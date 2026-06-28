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
    lower(hex(MD5(concat(toString(_source_system), '|', toString(employee_id))))) AS employee_sk,
    _source_system,
    employee_id AS natural_employee_id,
    trim(first_name) AS first_name,
    trim(last_name) AS last_name,
    trim(employee_email) AS email,
    CAST(hire_date AS Nullable(Date)) AS hire_date,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(warehouse_id))))) AS warehouse_sk,
    now() AS _silver_loaded_at
FROM employees
