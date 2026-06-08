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
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(order_id, 0)))))) AS order_sk,
    'ecommerce' AS source_system,
    order_id AS original_order_id,
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(customer_id, 0)))))) AS customer_sk,
    toUInt32(toYYYYMMDD(order_created_at)) AS date_id,
    trim(order_status) AS order_status,
    total_amount,
    now() AS _silver_loaded_at
FROM ecom_orders

UNION ALL

SELECT
    lower(hex(MD5(concat('instacart-', toString(coalesce(order_id, 0)))))) AS order_sk,
    'instacart' AS source_system,
    order_id AS original_order_id,
    lower(hex(MD5('unknown'))) AS customer_sk,
    CAST(NULL AS Nullable(UInt32)) AS date_id,
    CAST(NULL AS Nullable(String)) AS order_status,
    CAST(NULL AS Nullable(Decimal(18,2))) AS total_amount,
    now() AS _silver_loaded_at
FROM instacart_orders
