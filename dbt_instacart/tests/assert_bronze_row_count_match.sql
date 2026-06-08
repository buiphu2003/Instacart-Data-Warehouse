
SELECT 'orders' AS table_name,
       s.cnt AS source_count,
       m.cnt AS model_count,
       s.cnt - m.cnt AS difference
FROM (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'orders') }}) AS s,
     (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_orders') }}) AS m
WHERE s.cnt != m.cnt

UNION ALL

SELECT 'order_items' AS table_name,
       s.cnt AS source_count,
       m.cnt AS model_count,
       s.cnt - m.cnt AS difference
FROM (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'order_items') }}) AS s,
     (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_order_items') }}) AS m
WHERE s.cnt != m.cnt

UNION ALL

SELECT 'customers' AS table_name,
       s.cnt AS source_count,
       m.cnt AS model_count,
       s.cnt - m.cnt AS difference
FROM (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'customers') }}) AS s,
     (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_customers') }}) AS m
WHERE s.cnt != m.cnt

UNION ALL

SELECT 'products' AS table_name,
       s.cnt AS source_count,
       m.cnt AS model_count,
       s.cnt - m.cnt AS difference
FROM (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'products') }}) AS s,
     (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_products') }}) AS m
WHERE s.cnt != m.cnt
