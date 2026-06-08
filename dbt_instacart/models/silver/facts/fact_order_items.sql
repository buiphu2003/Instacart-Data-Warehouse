{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='order_item_sk'
) }}

WITH ecom_items AS (
    SELECT *
    FROM {{ ref('base_ecommerce_order_items') }}
),

instacart_prior AS (
    SELECT *
    FROM {{ ref('base_instacart_order_products_prior') }}
),

instacart_train AS (
    SELECT *
    FROM {{ ref('base_instacart_order_products_train') }}
),

instacart_items AS (
    SELECT * FROM instacart_prior
    UNION ALL
    SELECT * FROM instacart_train
)

SELECT
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(order_id, 0)), '-', toString(coalesce(product_id, 0)))))) AS order_item_sk,
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(order_id, 0)))))) AS order_sk,
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(product_id, 0)))))) AS product_sk,
    'ecommerce' AS source_system,
    coalesce(quantity, 1) AS quantity,
    unit_price,
    subtotal AS total_price,
    CAST(NULL AS Nullable(UInt16)) AS add_to_cart_order,
    CAST(NULL AS Nullable(UInt8)) AS is_reordered,
    now() AS _silver_loaded_at
FROM ecom_items

UNION ALL

SELECT
    lower(hex(MD5(concat('instacart-', toString(coalesce(order_id, 0)), '-', toString(coalesce(product_id, 0)))))) AS order_item_sk,
    lower(hex(MD5(concat('instacart-', toString(coalesce(order_id, 0)))))) AS order_sk,
    lower(hex(MD5(concat('instacart-', toString(coalesce(product_id, 0)))))) AS product_sk,
    'instacart' AS source_system,
    1 AS quantity,
    CAST(NULL AS Nullable(Decimal(18,2))) AS unit_price,
    CAST(NULL AS Nullable(Decimal(18,2))) AS total_price,
    add_to_cart_order,
    reordered AS is_reordered,
    now() AS _silver_loaded_at
FROM instacart_items
