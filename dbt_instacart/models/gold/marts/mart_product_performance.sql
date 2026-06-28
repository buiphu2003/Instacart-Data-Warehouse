{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='product_sk'
) }}

WITH order_items AS (
    SELECT 
        product_sk,
        sum(quantity) AS total_quantity_sold,
        sum(total_price) AS total_revenue_generated
    FROM {{ ref('fact_order_items') }}
    GROUP BY product_sk
),
returns AS (
    SELECT
        i.product_sk,
        count(r.return_sk) AS return_count
    FROM {{ ref('fact_returns') }} r
    LEFT JOIN {{ ref('fact_order_items') }} i ON r.order_sk = i.order_sk
    GROUP BY i.product_sk
),
products AS (
    SELECT *
    FROM {{ ref('dim_products') }}
)

SELECT 
    assumeNotNull(p.product_sk) AS product_sk,
    p.product_name AS product_name,
    p.category_name AS category_name,
    p.supplier_name AS supplier_name,
    
    coalesce(oi.total_quantity_sold, 0) AS total_quantity_sold,
    coalesce(oi.total_revenue_generated, 0) AS total_revenue_generated,
    coalesce(r.return_count, 0) AS return_count,
    
    if(coalesce(oi.total_quantity_sold, 0) > 0, 
       coalesce(r.return_count, 0) / oi.total_quantity_sold, 
       0) AS return_rate,
       
    now() AS _gold_loaded_at
FROM products p
LEFT JOIN order_items oi ON p.product_sk = oi.product_sk
LEFT JOIN returns r ON p.product_sk = r.product_sk
