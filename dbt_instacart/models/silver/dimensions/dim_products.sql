{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='product_sk',
    unique_key='product_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : dim_products
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_products + base_instacart_products (Bronze)
-- STRATEGY: incremental — unique_key=product_sk
--           Ecom: filter trên products._bronze_loaded_at — categories và suppliers
--           luôn được JOIN latest (không filter riêng) vì:
--             - Nếu product thay đổi → _bronze_loaded_at mới → Silver pick up
--             - Nếu category/supplier thay đổi → product chưa đổi → LEFT JOIN
--               vẫn lấy được giá trị mới nhất của category/supplier từ Bronze
--           Instacart: CSV tĩnh, UPSERT đảm bảo idempotent
-- ============================================================

WITH ecom_products AS (
    SELECT
        p.product_id AS product_id,
        p.product_name AS product_name,
        p.price AS price,
        p._source_system AS _source_system,
        p._bronze_loaded_at AS _bronze_loaded_at,
        c.category_name AS category_name,
        s.supplier_name AS supplier_name
    FROM {{ ref('base_ecommerce_products') }} p
    LEFT JOIN {{ ref('base_ecommerce_categories') }} c ON p.category_id = c.category_id
    LEFT JOIN {{ ref('base_ecommerce_suppliers') }} s ON p.supplier_id = s.supplier_id
    {% if is_incremental() %}
    -- Filter trên bảng chính (products). Categories/suppliers luôn JOIN latest từ Bronze
    WHERE p._bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
       OR c._bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
       OR s._bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
),

instacart_products AS (
    SELECT
        p.product_id AS product_id,
        p.product_name AS product_name,
        p._source_system AS _source_system,
        p._bronze_loaded_at AS _bronze_loaded_at,
        d.department_name AS category_name,
        a.aisle_name AS sub_category_name
    FROM {{ ref('base_instacart_products') }} p
    LEFT JOIN {{ ref('base_instacart_departments') }} d ON p.department_id = d.department_id
    LEFT JOIN {{ ref('base_instacart_aisles') }} a ON p.aisle_id = a.aisle_id
    {% if is_incremental() %}
    WHERE p._bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
