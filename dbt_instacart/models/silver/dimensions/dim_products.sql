{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='product_sk'
) }}

WITH ecom_products AS (
    SELECT p.product_id, p.product_name, p.price, p._source_system AS _source_system, c.category_name, s.supplier_name
    FROM {{ ref('base_ecommerce_products') }} p
    LEFT JOIN {{ ref('base_ecommerce_categories') }} c ON p.category_id = c.category_id
    LEFT JOIN {{ ref('base_ecommerce_suppliers') }} s ON p.supplier_id = s.supplier_id
),

instacart_products AS (
    SELECT p.product_id, p.product_name, p._source_system AS _source_system, d.department_name AS category_name, a.aisle_name AS sub_category_name
    FROM {{ ref('base_instacart_products') }} p
    LEFT JOIN {{ ref('base_instacart_departments') }} d ON p.department_id = d.department_id
    LEFT JOIN {{ ref('base_instacart_aisles') }} a ON p.aisle_id = a.aisle_id
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(product_id))))) AS product_sk,
    _source_system,
    toString(product_id) AS natural_product_id,
    coalesce(trim(product_name), 'Unknown') AS product_name,
    coalesce(trim(category_name), 'Unknown') AS category_name,
    'N/A' AS sub_category_name,
    coalesce(trim(supplier_name), 'Unknown') AS supplier_name,
    price AS current_price,
    now() AS _silver_loaded_at
FROM ecom_products

UNION ALL

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(product_id))))) AS product_sk,
    _source_system,
    toString(product_id) AS natural_product_id,
    coalesce(trim(product_name), 'Unknown') AS product_name,
    coalesce(trim(category_name), 'Unknown') AS category_name,
    coalesce(trim(sub_category_name), 'Unknown') AS sub_category_name,
    'N/A' AS supplier_name,
    CAST(NULL AS Nullable(Decimal(18,2))) AS current_price,
    now() AS _silver_loaded_at
FROM instacart_products
