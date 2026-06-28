{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='tuple()'
) }}

WITH customers AS (
    SELECT * 
    FROM {{ ref('dim_customers') }}
    WHERE _source_system = 'ecommerce_postgres'
),
orders AS (
    SELECT 
        customer_sk,
        MAX(toDate(toString(date_id), 'YYYYMMDD')) AS last_order_date,
        COUNT(order_sk) AS frequency,
        SUM(total_amount) AS monetary
    FROM {{ ref('fact_orders') }}
    WHERE _source_system = 'ecommerce_postgres'
    GROUP BY customer_sk
)

SELECT
    c.customer_sk AS customer_sk,
    c.natural_customer_id AS natural_customer_id,
    c.first_name AS first_name,
    c.last_name AS last_name,
    c.email AS email,
    c.loyalty_tier AS loyalty_tier,
    
    o.last_order_date,
    dateDiff('day', o.last_order_date, toDate(now())) AS recency,
    coalesce(o.frequency, 0) AS frequency,
    coalesce(o.monetary, 0) AS monetary,
    
    -- Phân loại RFM cơ bản
    CASE
        WHEN dateDiff('day', o.last_order_date, toDate(now())) <= 30 AND coalesce(o.frequency, 0) >= 5 THEN 'VIP'
        WHEN dateDiff('day', o.last_order_date, toDate(now())) > 90 AND coalesce(o.frequency, 0) <= 1 THEN 'Churned'
        WHEN dateDiff('day', o.last_order_date, toDate(now())) <= 30 AND coalesce(o.frequency, 0) <= 2 THEN 'New'
        ELSE 'Regular'
    END AS rfm_segment,
    
    now() AS _gold_loaded_at
FROM customers c
LEFT JOIN orders o ON c.customer_sk = o.customer_sk
