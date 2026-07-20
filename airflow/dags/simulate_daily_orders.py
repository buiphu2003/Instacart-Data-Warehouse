from airflow import DAG
# pyrefly: ignore [missing-import]
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import random
import psycopg2

# Cấu hình kết nối tới Postgres CRM
DB_USER = "crm_user"
DB_PASS = "crm_pass"
DB_HOST = "postgres_crm" # Tên container của Postgres CRM trong docker-compose
DB_PORT = "5432"
DB_NAME = "crm_db"
SCHEMA_NAME = "ecommerce"

NUM_DAILY_ORDERS = 100 # Số lượng đơn hàng sinh ra mỗi ngày

def generate_daily_orders(**kwargs):
    # Lấy Execution Date của Airflow (ngày giả lập chạy DAG)
    execution_date = kwargs['execution_date']
    
    # Kết nối trực tiếp vào Postgres bằng psycopg2
    conn = psycopg2.connect(
        user=DB_USER, password=DB_PASS, 
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME
    )
    conn.autocommit = False # Tắt autocommit để gộp chung 1 transaction
    cursor = conn.cursor()

    try:
        # Lấy MAX ID hiện tại của các bảng để tiếp tục sinh ID
        cursor.execute(f"SELECT COALESCE(MAX(order_id), 0) FROM {SCHEMA_NAME}.orders;")
        order_id_counter = cursor.fetchone()[0] + 1
        
        cursor.execute(f"SELECT COALESCE(MAX(payment_id), 0) FROM {SCHEMA_NAME}.payments;")
        payment_id_counter = cursor.fetchone()[0] + 1

        cursor.execute(f"SELECT COALESCE(MAX(shipment_id), 0) FROM {SCHEMA_NAME}.shipments;")
        shipment_id_counter = cursor.fetchone()[0] + 1

        cursor.execute(f"SELECT COALESCE(MAX(return_id), 0) FROM {SCHEMA_NAME}.returns;")
        return_id_counter = cursor.fetchone()[0] + 1

        # Lấy danh sách Product IDs và giá
        cursor.execute(f"SELECT product_id, price FROM {SCHEMA_NAME}.products;")
        products = cursor.fetchall()
        product_price_map = {row[0]: float(row[1]) for row in products}
        valid_product_ids = list(product_price_map.keys())

        # Lấy danh sách Customer IDs và Warehouse IDs
        cursor.execute(f"SELECT customer_id FROM {SCHEMA_NAME}.customers;")
        valid_customer_ids = [row[0] for row in cursor.fetchall()]

        cursor.execute(f"SELECT warehouse_id FROM {SCHEMA_NAME}.warehouses;")
        valid_warehouse_ids = [row[0] for row in cursor.fetchall()]

        orders, order_items, payments, shipments, returns = [], [], [], [], []

        for _ in range(NUM_DAILY_ORDERS):
            # Tạo thời gian ngẫu nhiên trong ngày execution_date
            order_time = execution_date + timedelta(
                hours=random.randint(0, 23), 
                minutes=random.randint(0, 59), 
                seconds=random.randint(0, 59)
            )
            
            customer_id = random.choice(valid_customer_ids)
            status = random.choices(['PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED'], weights=[5, 10, 15, 65, 5])[0]
            
            total_amount = 0
            items_in_order = random.randint(1, 5)
            
            for _ in range(items_in_order):
                product_id = random.choice(valid_product_ids)
                unit_price = product_price_map[product_id]
                qty = random.randint(1, 3)
                subtotal = round(qty * unit_price, 2)
                total_amount += subtotal
                
                order_items.append((order_id_counter, product_id, qty, unit_price, subtotal))
                
            total_amount = round(total_amount, 2)
            orders.append((order_id_counter, customer_id, order_time, status, total_amount))
            
            # Khởi tạo Payment
            payment_status = 'SUCCESS' if status != 'CANCELLED' else random.choice(['FAILED', 'REFUNDED'])
            payment_date = order_time + timedelta(minutes=random.randint(1, 60))
            payments.append((payment_id_counter, order_id_counter, random.choice(['CREDIT_CARD', 'PAYPAL', 'BANK_TRANSFER', 'COD']), total_amount, payment_date, payment_status))
            payment_id_counter += 1
            
            # Khởi tạo Shipment
            if status in ['SHIPPED', 'DELIVERED']:
                shipment_date = order_time + timedelta(days=random.randint(1, 3))
                shipments.append((shipment_id_counter, order_id_counter, random.choice(valid_warehouse_ids), shipment_date, random.choice(['FedEx', 'UPS', 'DHL', 'USPS']), 'DELIVERED' if status == 'DELIVERED' else 'IN_TRANSIT'))
                shipment_id_counter += 1
                
            # Khởi tạo Return
            if status == 'DELIVERED' and random.random() < 0.05:
                return_date = order_time + timedelta(days=random.randint(5, 30))
                returns.append((return_id_counter, order_id_counter, customer_id, return_date, random.choice(['DEFECTIVE', 'WRONG_ITEM', 'NOT_AS_EXPECTED', 'CHANGED_MIND']), random.choice(['PENDING', 'APPROVED', 'REJECTED'])))
                return_id_counter += 1

            order_id_counter += 1

        # Thực thi Insert vào DB
        from psycopg2.extras import execute_values
        
        execute_values(cursor, f"INSERT INTO {SCHEMA_NAME}.orders (order_id, customer_id, order_date, status, total_amount) VALUES %s", orders)
        execute_values(cursor, f"INSERT INTO {SCHEMA_NAME}.order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES %s", order_items)
        execute_values(cursor, f"INSERT INTO {SCHEMA_NAME}.payments (payment_id, order_id, payment_method, amount, payment_date, status) VALUES %s", payments)
        execute_values(cursor, f"INSERT INTO {SCHEMA_NAME}.shipments (shipment_id, order_id, warehouse_id, shipment_date, carrier, status) VALUES %s", shipments)
        if returns:
            execute_values(cursor, f"INSERT INTO {SCHEMA_NAME}.returns (return_id, order_id, customer_id, return_date, reason, status) VALUES %s", returns)

        conn.commit()
        print(f"✅ Đã tạo thành công {NUM_DAILY_ORDERS} đơn hàng cho ngày {execution_date.date()}")
        
    except Exception as e:
        conn.rollback()
        print(f"❌ Lỗi: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

# Định nghĩa DAG
default_args = {
    'owner': 'data_engineer',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    'simulate_daily_ecommerce_orders',
    default_args=default_args,
    description='DAG giả lập sinh 100 đơn hàng mới vào Postgres CRM mỗi ngày',
    schedule_interval='@daily',
    start_date=datetime(2026, 7, 10), # Có thể tùy chỉnh ngày bắt đầu
    catchup=False,
    tags=['simulation', 'ecommerce'],
) as dag:

    generate_data_task = PythonOperator(
        task_id='generate_100_orders',
        python_callable=generate_daily_orders,
        provide_context=True
    )
