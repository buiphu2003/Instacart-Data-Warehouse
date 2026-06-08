{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='product_sk'
) }}

WITH ecom_products AS (
    SELECT p.*, c.category_name
    FROM {{ ref('base_ecommerce_products') }} p
    LEFT JOIN {{ ref('base_ecommerce_categories') }} c ON p.category_id = c.category_id
    WHERE p.is_current = 'true'
),

instacart_products AS (
    SELECT p.*, d.department_name AS category_name, a.aisle_name AS sub_category_name
    FROM {{ ref('base_instacart_products') }} p
    LEFT JOIN {{ ref('base_instacart_departments') }} d ON p.department_id = d.department_id
    LEFT JOIN {{ ref('base_instacart_aisles') }} a ON p.aisle_id = a.aisle_id
)

SELECT
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(product_id, 0)))))) AS product_sk,
    'ecommerce' AS source_system,
    product_id AS original_product_id,
    trim(product_name) AS product_name,
    trim(category_name) AS category_name,
    CAST(NULL AS Nullable(String)) AS sub_category_name,
    price AS current_price,
    now() AS _silver_loaded_at
FROM ecom_products

UNION ALL

SELECT
    lower(hex(MD5(concat('instacart-', toString(coalesce(product_id, 0)))))) AS product_sk,
    'instacart' AS source_system,
    product_id AS original_product_id,
    trim(product_name) AS product_name,
    trim(category_name) AS category_name,
    trim(sub_category_name) AS sub_category_name,
    CAST(NULL AS Nullable(Decimal(18,2))) AS current_price,
    now() AS _silver_loaded_at
FROM instacart_products
