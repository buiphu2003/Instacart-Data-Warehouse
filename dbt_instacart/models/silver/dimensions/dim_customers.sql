{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='customer_sk',
    unique_key='customer_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : dim_customers
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_customers + base_instacart_orders (Bronze)
-- STRATEGY: incremental — unique_key=customer_sk
--           Ecom: Watermark _bronze_loaded_at > max(_silver_loaded_at)
--           Instacart: CSV tĩnh, filter cùng watermark — UPSERT đảm bảo
--           không duplicate dù instacart Bronze rebuild toàn bộ
-- ============================================================

WITH ecom_customers AS (
    SELECT 
        *,
        valid_from AS true_customer_since
    FROM {{ ref('base_ecommerce_customers') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
),

instacart_customers AS (
    SELECT DISTINCT 
        user_id, 
        _source_system,
        _bronze_loaded_at
    FROM {{ ref('base_instacart_orders') }}
    {% if is_incremental() %}
    -- CSV tĩnh: chỉ flow khi Bronze instacart rebuild. UPSERT theo customer_sk đảm bảo idempotent
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(customer_id))))) AS customer_sk,
    _source_system,
    toString(customer_id) AS natural_customer_id,
    coalesce(trim(first_name), 'Unknown') AS first_name,    
    coalesce(trim(last_name), 'Unknown') AS last_name,
    coalesce(trim(customer_email), 'Unknown') AS email,
    coalesce(trim(customer_phone), 'Unknown') AS phone,
    coalesce(trim(customer_address), 'Unknown') AS address,
    CASE 
        WHEN lower(loyalty_tier) IN ('bronz', 'bronze') THEN 'Bronze'
        WHEN lower(loyalty_tier) IN ('silvr', 'silver') THEN 'Silver'
        WHEN lower(loyalty_tier) IN ('gol', 'gold') THEN 'Gold'
        WHEN lower(loyalty_tier) IN ('plat', 'platinum') THEN 'Platinum'
        ELSE coalesce(loyalty_tier, 'Unknown')
    END AS loyalty_tier,
    true_customer_since AS customer_since,
    now() AS _silver_loaded_at
FROM ecom_customers

UNION ALL

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(user_id))))) AS customer_sk,
    _source_system,
    toString(user_id) AS natural_customer_id,
    'Unknown' AS first_name,    
    'Unknown' AS last_name,
    'Unknown' AS email,
    'Unknown' AS phone,
    'Unknown' AS address,
    'Unknown' AS loyalty_tier,
    CAST(NULL AS Nullable(DateTime)) AS customer_since,
    now() AS _silver_loaded_at
FROM instacart_customers
