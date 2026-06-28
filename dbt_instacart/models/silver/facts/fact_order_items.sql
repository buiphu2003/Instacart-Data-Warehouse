{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='order_item_sk'
) }}

WITH ecom_items AS (
    SELECT 
        _source_system,
        order_id,
        product_id,
        max(unit_price) AS unit_price,
        sum(quantity) AS quantity,
        sum(subtotal) AS subtotal
    FROM {{ ref('base_ecommerce_order_items') }}
    GROUP BY _source_system, order_id, product_id
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
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id), '|', toString(product_id))))) AS order_item_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(product_id))))) AS product_sk,
    _source_system,
    coalesce(quantity, 1) AS quantity,
    unit_price,
    subtotal AS total_price,
    CAST(NULL AS Nullable(UInt16)) AS add_to_cart_order,  -- NULL cho ecommerce (chỉ Instacart có)
    CAST(NULL AS Nullable(UInt8))  AS is_reordered,       -- NULL cho ecommerce (chỉ Instacart có)
    now() AS _silver_loaded_at
FROM ecom_items

UNION ALL

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id), '|', toString(product_id))))) AS order_item_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(product_id))))) AS product_sk,
    _source_system,
    1 AS quantity,
    CAST(NULL AS Nullable(Decimal(18,2))) AS unit_price,
    CAST(NULL AS Nullable(Decimal(18,2))) AS total_price,
    add_to_cart_order,
    reordered AS is_reordered,
    now() AS _silver_loaded_at
FROM instacart_items
