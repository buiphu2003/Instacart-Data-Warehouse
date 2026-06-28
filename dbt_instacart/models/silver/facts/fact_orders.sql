{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='order_sk'
) }}

WITH ecom_orders AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_orders') }}
),

instacart_orders AS (
    SELECT *
    FROM {{ ref('base_instacart_orders') }}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    _source_system,
    order_id AS natural_order_id,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(customer_id))))) AS customer_sk,
    toUInt32(toYYYYMMDD(order_created_at)) AS date_id,
    trim(order_status) AS order_status,
    total_amount,
    now() AS _silver_loaded_at
FROM ecom_orders

UNION ALL

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    _source_system,
    order_id AS natural_order_id,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(user_id))))) AS customer_sk,
    toUInt32(0) AS date_id,
    'N/A' AS order_status,
    CAST(0 AS Nullable(Decimal(18,2))) AS total_amount,
    now() AS _silver_loaded_at
FROM instacart_orders
