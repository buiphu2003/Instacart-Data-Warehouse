{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='supplier_sk'
) }}

WITH suppliers AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_suppliers') }}
)

SELECT
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(supplier_id, 0)))))) AS supplier_sk,
    supplier_id AS original_supplier_id,
    trim(supplier_name) AS supplier_name,
    trim(contact_email) AS contact_email,
    trim(contact_phone) AS contact_phone,
    trim(country) AS country,
    now() AS _silver_loaded_at
FROM suppliers
