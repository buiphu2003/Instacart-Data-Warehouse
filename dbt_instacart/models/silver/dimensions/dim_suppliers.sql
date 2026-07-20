{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='supplier_sk',
    unique_key='supplier_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : dim_suppliers
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_suppliers (Bronze)
-- STRATEGY: incremental — unique_key=supplier_sk
--           Watermark: _bronze_loaded_at > max(_silver_loaded_at)
--           Cả hai đều là ClickHouse DateTime → không cần macro xử lý type
-- ============================================================

WITH suppliers AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_suppliers') }}
    {% if is_incremental() %}
    -- Chỉ lấy suppliers mà Bronze vừa load mới kể từ lần Silver chạy trước
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
