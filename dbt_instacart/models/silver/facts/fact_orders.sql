{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='order_sk',
    unique_key='order_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_orders
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_orders + base_instacart_orders (Bronze)
-- STRATEGY: incremental — unique_key=order_sk (UPSERT current state)
--           Ecom: chỉ lấy dbt_valid_to IS NULL (current state) từ snapshot
--                 Filter theo _bronze_loaded_at > max(_silver_loaded_at)
--           Instacart: CSV tĩnh, filter cùng watermark, UPSERT idempotent
-- ============================================================

WITH ecom_orders AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_orders') }}
    WHERE dbt_valid_to IS NULL  -- Chỉ lấy current state của mỗi order
    {% if is_incremental() %}
    AND _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
),

instacart_orders AS (
    SELECT *
    FROM {{ ref('base_instacart_orders') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
