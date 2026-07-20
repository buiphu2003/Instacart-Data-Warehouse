{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='order_item_sk',
    unique_key='order_item_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_order_items
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_order_items + base_instacart_order_products_* (Bronze)
-- STRATEGY: incremental — unique_key=order_item_sk
--           Ecom: INSERT-only ở source → filter _bronze_loaded_at > max
--           Instacart: CSV tĩnh (prior + train), UPSERT idempotent
-- ============================================================

WITH ecom_items AS (
    SELECT 
        _source_system,
        order_id,
        product_id,
        _bronze_loaded_at,
        max(unit_price) AS unit_price,
        sum(quantity) AS quantity,
        sum(subtotal) AS subtotal
    FROM {{ ref('base_ecommerce_order_items') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
    GROUP BY _source_system, order_id, product_id, _bronze_loaded_at
),

instacart_prior AS (
    SELECT *
    FROM {{ ref('base_instacart_order_products_prior') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
),

instacart_train AS (
    SELECT *
    FROM {{ ref('base_instacart_order_products_train') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
    CAST(NULL AS Nullable(UInt16)) AS add_to_cart_order,
    CAST(NULL AS Nullable(UInt8))  AS is_reordered,
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
