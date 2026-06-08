{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='employee_sk'
) }}

WITH employees AS (
    SELECT *
    FROM {{ ref('base_ecommerce_employees') }}
)

SELECT
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(employee_id, 0)))))) AS employee_sk,
    employee_id AS original_employee_id,
    trim(first_name) AS first_name,
    trim(last_name) AS last_name,
    trim(employee_email) AS employee_email,
    CAST(hire_date AS Nullable(Date)) AS hire_date,
    warehouse_id,
    now() AS _silver_loaded_at
FROM employees
