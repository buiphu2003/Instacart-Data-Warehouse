{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='employee_sk',
    unique_key='employee_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : dim_employees
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_employees (Bronze)
-- STRATEGY: incremental — unique_key=employee_sk
--           Watermark: _bronze_loaded_at > max(_silver_loaded_at)
-- ============================================================

WITH employees AS (
    SELECT *
    FROM {{ ref('base_ecommerce_employees') }}
    {% if is_incremental() %}
    -- Chỉ lấy employees mà Bronze vừa load mới kể từ lần Silver chạy trước
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
