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
    lower(hex(MD5(concat(toString(_source_system), '|', toString(supplier_id))))) AS supplier_sk,
    _source_system,
    supplier_id AS natural_supplier_id,
    trim(supplier_name) AS supplier_name,
    trim(contact_email) AS supplier_email,
    trim(contact_phone) AS supplier_phone,
    trim(country) AS supplier_country,
    now() AS _silver_loaded_at
FROM suppliers
