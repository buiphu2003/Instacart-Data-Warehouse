{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='date_id'
) }}

WITH orders AS (
    SELECT * 
    FROM {{ ref('fact_orders') }}
    WHERE _source_system = 'ecommerce_postgres'
),
dates AS (
    SELECT * 
    FROM {{ ref('dim_date') }}
)

SELECT 
    d.date_id,
    d.date AS full_date,
    d.day_of_week,
    d.is_weekend,
    count(o.order_sk) AS total_orders,
    sum(coalesce(o.total_amount, 0)) AS total_revenue,
    if(count(o.order_sk) > 0, sum(coalesce(o.total_amount, 0)) / count(o.order_sk), 0) AS average_order_value,
    now() AS _gold_loaded_at
FROM dates d
LEFT JOIN orders o ON d.date_id = o.date_id
GROUP BY 
    d.date_id,
    d.date,
    d.day_of_week,
    d.is_weekend
