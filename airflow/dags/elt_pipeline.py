from datetime import datetime, timedelta
from airflow import DAG
# pyrefly: ignore [missing-import]
from airflow.operators.bash import BashOperator

# Các tham số mặc định cho DAG
default_args = {
    'owner': 'data_engineer',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

# Khởi tạo DAG
with DAG(
    'instacart_elt_pipeline',
    default_args=default_args,
    description='A simple ELT pipeline running dbt models',
    schedule_interval='*/5 * * * *', # Chạy mỗi 5 phút (để test)
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['dbt', 'instacart'],
) as dag:

    # Task 1: Chạy dbt deps (để tải packages nếu cần)
    dbt_deps = BashOperator(
        task_id='dbt_deps',
        bash_command='cd /opt/airflow/dbt_instacart && dbt deps',
    )

    # Task 2: Chạy lớp Bronze
    dbt_run_bronze = BashOperator(
        task_id='dbt_run_bronze',
        bash_command='cd /opt/airflow/dbt_instacart && dbt run --models bronze.*',
    )

    # Task 3: Chạy lớp Silver
    dbt_run_silver = BashOperator(
        task_id='dbt_run_silver',
        bash_command='cd /opt/airflow/dbt_instacart && dbt run --models silver.*',
    )

    # Task 4: Chạy lớp Gold
    dbt_run_gold = BashOperator(
        task_id='dbt_run_gold',
        bash_command='cd /opt/airflow/dbt_instacart && dbt run --models gold.*',
    )

    # Định nghĩa luồng (dependencies)
    dbt_deps >> dbt_run_bronze >> dbt_run_silver >> dbt_run_gold
