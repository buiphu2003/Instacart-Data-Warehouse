{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='warehouse_sk',
    unique_key='warehouse_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : dim_warehouses
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_warehouses (Bronze)
-- STRATEGY: incremental — unique_key=warehouse_sk
--           Watermark: _bronze_loaded_at > max(_silver_loaded_at)
-- ============================================================

WITH warehouses AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_warehouses') }}
    {% if is_incremental() %}
    -- Chỉ lấy warehouses mà Bronze vừa load mới kể từ lần Silver chạy trước
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(warehouse_id))))) AS warehouse_sk,
    _source_system,
    warehouse_id AS natural_warehouse_id,
    trim(warehouse_name) AS warehouse_name,
    trim(location) AS warehouse_location,
    capacity,
    now() AS _silver_loaded_at
FROM warehouses
