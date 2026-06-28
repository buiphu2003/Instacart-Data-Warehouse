{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='return_sk',
    settings={'allow_nullable_key': 1}
) }}

WITH returns AS (
    SELECT * 
    FROM {{ ref('fact_returns') }}
),
orders AS (
    SELECT * 
    FROM {{ ref('fact_orders') }}
),
customers AS (
    SELECT * 
    FROM {{ ref('dim_customers') }}
)

SELECT 
    r.return_sk AS return_sk,
    r.order_sk AS order_sk,
    r.natural_return_id AS natural_return_id,
    r.date_id AS return_date_id,
    r.return_reason AS return_reason,
    r.return_status AS return_status,
    
    o.natural_order_id AS natural_order_id,
    o.date_id AS original_order_date_id,
    o.total_amount AS original_order_amount,
    
    c.customer_sk AS customer_sk,
    c.loyalty_tier AS loyalty_tier,
    
    now() AS _gold_loaded_at
FROM returns r
LEFT JOIN orders o ON r.order_sk = o.order_sk
LEFT JOIN customers c ON r.customer_sk = c.customer_sk
