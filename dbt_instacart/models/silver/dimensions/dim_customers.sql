{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='customer_id'
) }}

WITH customers AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_customers') }}
    WHERE is_current = 'true'
)

SELECT
    coalesce(customer_id, 0) AS customer_id,
    trim(first_name) AS first_name,
    trim(last_name) AS last_name,
    trim(customer_email) AS email,
    trim(customer_phone) AS phone,
    trim(customer_address) AS address,
    CASE 
        WHEN lower(loyalty_tier) IN ('bronz', 'bronze') THEN 'Bronze'
        WHEN lower(loyalty_tier) IN ('silvr', 'silver') THEN 'Silver'
        WHEN lower(loyalty_tier) IN ('gol', 'gold') THEN 'Gold'
        WHEN lower(loyalty_tier) IN ('plat', 'platinum') THEN 'Platinum'
        ELSE coalesce(loyalty_tier, 'Unknown')
    END AS loyalty_tier,
    valid_from AS customer_since,
    now() AS _silver_loaded_at
FROM customers
