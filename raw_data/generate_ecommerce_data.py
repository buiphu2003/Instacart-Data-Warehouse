import io
import os
import random
import logging
import time
import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text
import psycopg2

# ==========================================
# CẤU HÌNH HỆ THỐNG VÀ THAM SỐ
# ==========================================
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Thông tin Database
DB_USER = "crm_user"
DB_PASS = "crm_pass"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "crm_db"
SCHEMA_NAME = "ecommerce"

# Seed & Faker
RANDOM_SEED = 42
Faker.seed(RANDOM_SEED)
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)
fake = Faker()

# Chế độ
MODE = 'FULL' 
INCREMENTAL_START_DATE = datetime(2025, 12, 31)
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime.now()

# Quy mô dữ liệu (Đã giảm xuống để test nhanh)
NUM_CUSTOMERS = 10_000
NUM_PRODUCTS = 5_000
NUM_SUPPLIERS = 100
NUM_EMPLOYEES = 50
NUM_WAREHOUSES = 5
NUM_CATEGORIES = 20

# Transaction Data
TOTAL_ORDERS = 100_000
BATCH_SIZE = 50_000 # Rút nhỏ batch size lại cho phù hợp
ERROR_RATE = 0.015

initialized_tables = set()

# ==========================================
# DATABASE HELPER (Bắn data trực tiếp vào RAM)
# ==========================================
def fast_pg_insert(df: pd.DataFrame, table_name: str, engine, cursor):
    """Sử dụng Pandas tạo bảng, và io.StringIO kết hợp COPY để bắn data không qua đĩa cứng"""
    if df.empty: return
    
    # Lần đầu tiên gọi hàm cho bảng này, ta dùng pandas để gen DDL (CREATE TABLE)
    if table_name not in initialized_tables:
        if_exists_action = 'replace' if MODE == 'FULL' else 'append'
        # Đẩy head(0) để tạo cấu trúc bảng rất nhanh
        df.head(0).to_sql(name=table_name, schema=SCHEMA_NAME, con=engine, if_exists=if_exists_action, index=False)
        initialized_tables.add(table_name)
    
    # Bắn data qua RAM buffer bằng COPY
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=True)
    buffer.seek(0)
    
    copy_sql = f"COPY {SCHEMA_NAME}.{table_name} FROM STDIN WITH CSV HEADER"
    cursor.copy_expert(sql=copy_sql, file=buffer)

# ==========================================
# HÀM HỖ TRỢ & DATA QUALITY
# ==========================================
def get_random_date(start: datetime, end: datetime, seasonality: bool = False) -> datetime:
    delta = end - start
    random_days = random.randint(0, delta.days)
    base_date = start + timedelta(days=random_days)
    
    if seasonality:
        if random.random() < 0.4: 
            month = random.choice([11, 12])
            day = random.randint(1, 28)
            try: base_date = base_date.replace(month=month, day=day)
            except ValueError: pass
        if random.random() < 0.3: 
            while base_date.weekday() < 5:
                base_date += timedelta(days=1)
                
    return base_date + timedelta(seconds=random.randint(0, 86400))

def inject_data_quality_issues(df: pd.DataFrame) -> pd.DataFrame:
    if len(df) == 0: return df
    num_errors = int(len(df) * ERROR_RATE)
    
    if num_errors > 0:
        duplicates = df.sample(n=min(num_errors // 3, len(df)))
        df = pd.concat([df, duplicates], ignore_index=True)
    
    cols_to_null = [c for c in df.columns if 'id' not in c.lower()]
    if cols_to_null and num_errors > 0:
        for _ in range(num_errors // 3):
            df.at[random.randint(0, len(df) - 1), random.choice(cols_to_null)] = np.nan
            
    if 'email' in df.columns and num_errors > 0:
        for _ in range(num_errors // 3):
            row_idx = random.randint(0, len(df) - 1)
            if pd.notna(df.at[row_idx, 'email']):
                df.at[row_idx, 'email'] = df.at[row_idx, 'email'].replace('@', 'AT')

    return df

# ==========================================
# GENERATORS
# ==========================================
def generate_categories(engine, cursor):
    logger.info("Generating Categories...")
    data = [{'category_id': i + 1, 'category_name': fake.unique.word().capitalize(), 'parent_category_id': random.choice([None, random.randint(1, i)]) if i > 10 else None} for i in range(NUM_CATEGORIES)]
    fast_pg_insert(pd.DataFrame(data), 'categories', engine, cursor)

def generate_suppliers(engine, cursor):
    logger.info("Generating Suppliers...")
    data = [{'supplier_id': i + 1, 'supplier_name': fake.company(), 'contact_email': fake.company_email(), 'contact_phone': fake.phone_number(), 'country': fake.country()} for i in range(NUM_SUPPLIERS)]
    fast_pg_insert(pd.DataFrame(data), 'suppliers', engine, cursor)

def generate_warehouses(engine, cursor):
    logger.info("Generating Warehouses...")
    data = [{'warehouse_id': i + 1, 'warehouse_name': f"WH {fake.city()}", 'location': fake.address().replace('\n', ', '), 'capacity': random.randint(10000, 50000)} for i in range(NUM_WAREHOUSES)]
    fast_pg_insert(pd.DataFrame(data), 'warehouses', engine, cursor)

def generate_employees(engine, cursor):
    logger.info("Generating Employees...")
    data = [{'employee_id': i + 1, 'first_name': fake.first_name(), 'last_name': fake.last_name(), 'email': fake.email(), 'hire_date': fake.date_between(start_date=datetime(2020, 1, 1), end_date=datetime(2023, 1, 1)), 'warehouse_id': random.randint(1, NUM_WAREHOUSES)} for i in range(NUM_EMPLOYEES)]
    fast_pg_insert(pd.DataFrame(data), 'employees', engine, cursor)

def generate_customers(engine, cursor):
    logger.info("Generating Customers (SCD2)...")
    customers = []
    tiers = ['Bronze', 'Silver', 'Gold', 'Platinum']
    for i in range(1, NUM_CUSTOMERS + 1):
        created_at = get_random_date(datetime(2020, 1, 1), START_DATE)
        c = {'customer_id': i, 'first_name': fake.first_name(), 'last_name': fake.last_name(), 'email': fake.email(), 'phone': fake.phone_number(), 'address': fake.address().replace('\n', ', '), 'loyalty_tier': 'Bronze', 'valid_from': created_at, 'valid_to': datetime(9999, 12, 31), 'is_current': True}
        customers.append(c)
        if random.random() < 0.2:
            change_date = get_random_date(created_at, END_DATE)
            customers[-1]['valid_to'] = change_date
            customers[-1]['is_current'] = False
            customers.append({**c, 'address': fake.address().replace('\n', ', ') if random.random() < 0.5 else c['address'], 'loyalty_tier': random.choice(tiers[1:]), 'valid_from': change_date, 'valid_to': datetime(9999, 12, 31), 'is_current': True})
    df = inject_data_quality_issues(pd.DataFrame(customers))
    fast_pg_insert(df, 'customers', engine, cursor)

def generate_products(engine, cursor):
    logger.info("Generating Products (SCD2)...")
    products = []
    for i in range(1, NUM_PRODUCTS + 1):
        created_at = get_random_date(datetime(2020, 1, 1), START_DATE)
        p = {'product_id': i, 'product_name': fake.catch_phrase(), 'category_id': random.randint(1, NUM_CATEGORIES), 'supplier_id': random.randint(1, NUM_SUPPLIERS), 'price': round(random.uniform(10.0, 500.0), 2), 'valid_from': created_at, 'valid_to': datetime(9999, 12, 31), 'is_current': True}
        products.append(p)
        if random.random() < 0.3:
            change_date = get_random_date(START_DATE, END_DATE)
            products[-1]['valid_to'] = change_date
            products[-1]['is_current'] = False
            products.append({**p, 'price': round(p['price'] * random.uniform(0.9, 1.2), 2), 'supplier_id': random.randint(1, NUM_SUPPLIERS) if random.random() < 0.1 else p['supplier_id'], 'valid_from': change_date, 'valid_to': datetime(9999, 12, 31), 'is_current': True})
    df = inject_data_quality_issues(pd.DataFrame(products))
    fast_pg_insert(df, 'products', engine, cursor)

def generate_transactions(engine, cursor):
    logger.info(f"Generating Transactions: {TOTAL_ORDERS} orders in chunks of {BATCH_SIZE}...")
    
    order_id_counter, payment_id_counter, shipment_id_counter, return_id_counter = 1, 1, 1, 1
    valid_product_ids = np.arange(1, NUM_PRODUCTS + 1)
    
    for chunk_num in range(TOTAL_ORDERS // BATCH_SIZE):
        st = time.time()
        orders, order_items, payments, shipments, returns = [], [], [], [], []
        
        for _ in range(BATCH_SIZE):
            order_date = get_random_date(START_DATE, END_DATE, seasonality=True)
            if MODE == 'INCREMENTAL' and order_date < INCREMENTAL_START_DATE: continue
                
            customer_id = random.randint(1, NUM_CUSTOMERS)
            status = random.choices(['PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED'], weights=[5, 10, 15, 65, 5])[0]
            
            o = {'order_id': order_id_counter, 'customer_id': customer_id, 'order_date': order_date, 'status': status, 'total_amount': 0}
            orders.append(o)
            
            total_amount = 0
            for _ in range(random.randint(3, 5)):
                price = round(random.uniform(10.0, 500.0), 2)
                qty = random.randint(1, 3)
                subtotal = qty * price
                total_amount += subtotal
                order_items.append({'order_id': order_id_counter, 'product_id': random.choice(valid_product_ids), 'quantity': qty, 'unit_price': price, 'subtotal': subtotal})
            
            orders[-1]['total_amount'] = total_amount
            
            payment_status = 'SUCCESS' if status != 'CANCELLED' else random.choice(['FAILED', 'REFUNDED'])
            payments.append({'payment_id': payment_id_counter, 'order_id': order_id_counter, 'payment_method': random.choice(['CREDIT_CARD', 'PAYPAL', 'BANK_TRANSFER', 'COD']), 'amount': total_amount, 'payment_date': order_date + timedelta(minutes=random.randint(1, 60)), 'status': payment_status})
            payment_id_counter += 1
            
            if status in ['SHIPPED', 'DELIVERED']:
                shipments.append({'shipment_id': shipment_id_counter, 'order_id': order_id_counter, 'warehouse_id': random.randint(1, NUM_WAREHOUSES), 'shipment_date': order_date + timedelta(days=random.randint(1, 3)), 'carrier': random.choice(['FedEx', 'UPS', 'DHL', 'USPS']), 'status': 'DELIVERED' if status == 'DELIVERED' else 'IN_TRANSIT'})
                shipment_id_counter += 1
                
            if status == 'DELIVERED' and random.random() < 0.05:
                returns.append({'return_id': return_id_counter, 'order_id': order_id_counter, 'customer_id': customer_id, 'return_date': order_date + timedelta(days=random.randint(5, 30)), 'reason': random.choice(['DEFECTIVE', 'WRONG_ITEM', 'NOT_AS_EXPECTED', 'CHANGED_MIND']), 'status': random.choice(['PENDING', 'APPROVED', 'REJECTED'])})
                return_id_counter += 1

            order_id_counter += 1

        # Bắn trực tiếp vào DB
        if orders:
            fast_pg_insert(pd.DataFrame(orders), 'orders', engine, cursor)
            fast_pg_insert(pd.DataFrame(order_items), 'order_items', engine, cursor)
            fast_pg_insert(pd.DataFrame(payments), 'payments', engine, cursor)
            fast_pg_insert(pd.DataFrame(shipments), 'shipments', engine, cursor)
            fast_pg_insert(pd.DataFrame(returns), 'returns', engine, cursor)

        logger.info(f" -> Processed and Loaded chunk {chunk_num + 1}/{(TOTAL_ORDERS // BATCH_SIZE)} in {round(time.time() - st, 2)}s")

def add_constraints(conn, cursor):
    logger.info("--- THÊM RÀNG BUỘC (CONSTRAINTS) VÀO POSTGRESQL ---")
    queries = [
        # Khóa chính
        "ALTER TABLE ecommerce.categories ADD PRIMARY KEY (category_id);",
        "ALTER TABLE ecommerce.suppliers ADD PRIMARY KEY (supplier_id);",
        "ALTER TABLE ecommerce.warehouses ADD PRIMARY KEY (warehouse_id);",
        "ALTER TABLE ecommerce.employees ADD PRIMARY KEY (employee_id);",
        "ALTER TABLE ecommerce.orders ADD PRIMARY KEY (order_id);",
        "ALTER TABLE ecommerce.payments ADD PRIMARY KEY (payment_id);",
        "ALTER TABLE ecommerce.shipments ADD PRIMARY KEY (shipment_id);",
        "ALTER TABLE ecommerce.returns ADD PRIMARY KEY (return_id);",
        
        # Lưu ý: customers và products đang có dữ liệu SCD2 (trùng ID) nên không thể đặt PK đơn giản trên customer_id/product_id
        # "ALTER TABLE ecommerce.customers ADD PRIMARY KEY (customer_id);",
        # "ALTER TABLE ecommerce.products ADD PRIMARY KEY (product_id);",

        # Khóa ngoại
        "ALTER TABLE ecommerce.categories ADD CONSTRAINT fk_cat_parent FOREIGN KEY (parent_category_id) REFERENCES ecommerce.categories(category_id);",
        "ALTER TABLE ecommerce.employees ADD CONSTRAINT fk_emp_wh FOREIGN KEY (warehouse_id) REFERENCES ecommerce.warehouses(warehouse_id);",
        # "ALTER TABLE ecommerce.products ADD CONSTRAINT fk_prod_cat FOREIGN KEY (category_id) REFERENCES ecommerce.categories(category_id);",
        # "ALTER TABLE ecommerce.products ADD CONSTRAINT fk_prod_sup FOREIGN KEY (supplier_id) REFERENCES ecommerce.suppliers(supplier_id);",
        # "ALTER TABLE ecommerce.orders ADD CONSTRAINT fk_ord_cust FOREIGN KEY (customer_id) REFERENCES ecommerce.customers(customer_id);",
        "ALTER TABLE ecommerce.order_items ADD CONSTRAINT fk_oi_ord FOREIGN KEY (order_id) REFERENCES ecommerce.orders(order_id);",
        # "ALTER TABLE ecommerce.order_items ADD CONSTRAINT fk_oi_prod FOREIGN KEY (product_id) REFERENCES ecommerce.products(product_id);",
        "ALTER TABLE ecommerce.payments ADD CONSTRAINT fk_pay_ord FOREIGN KEY (order_id) REFERENCES ecommerce.orders(order_id);",
        "ALTER TABLE ecommerce.shipments ADD CONSTRAINT fk_ship_ord FOREIGN KEY (order_id) REFERENCES ecommerce.orders(order_id);",
        "ALTER TABLE ecommerce.shipments ADD CONSTRAINT fk_ship_wh FOREIGN KEY (warehouse_id) REFERENCES ecommerce.warehouses(warehouse_id);",
        "ALTER TABLE ecommerce.returns ADD CONSTRAINT fk_ret_ord FOREIGN KEY (order_id) REFERENCES ecommerce.orders(order_id);"
    ]
    
    for q in queries:
        try:
            cursor.execute(q)
            logger.info(f"Thành công: {q.split('ADD')[0].strip()} ...")
        except Exception as e:
            logger.warning(f"Bỏ qua constraint do vi phạm dữ liệu: {e}")

# ==========================================
# MAIN
# ==========================================
def main():
    logger.info("--- BẮT ĐẦU QUÁ TRÌNH SINH VÀ LOAD DỮ LIỆU IN-MEMORY ---")
    
    engine = create_engine(f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
    
    with engine.connect() as conn:
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA_NAME};"))
        conn.commit()
    
    conn = psycopg2.connect(user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT, dbname=DB_NAME)
    conn.autocommit = True
    cursor = conn.cursor()

    generate_categories(engine, cursor)
    generate_suppliers(engine, cursor)
    generate_warehouses(engine, cursor)
    generate_employees(engine, cursor)
    generate_customers(engine, cursor)
    generate_products(engine, cursor)
    
    generate_transactions(engine, cursor)

    # Thêm Khóa chính và Khóa ngoại vào PostgreSQL
    add_constraints(conn, cursor)

    cursor.close()
    conn.close()
    logger.info("--- HOÀN THÀNH ---")

if __name__ == "__main__":
    main()
