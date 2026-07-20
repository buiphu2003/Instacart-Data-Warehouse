{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='shipment_sk',
    unique_key='shipment_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_shipments
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_shipments (Bronze)
-- STRATEGY: incremental — unique_key=shipment_sk (UPSERT current state)
--           dbt_valid_to IS NULL → chỉ lấy trạng thái hiện tại của shipment
--           Khi status thay đổi (IN_TRANSIT→DELIVERED), snapshot tạo row mới
--           → Bronze load row mới → Silver UPSERT đè lên row cũ
-- ============================================================

WITH shipments AS (
    SELECT *
    FROM {{ ref('base_ecommerce_shipments') }}
    WHERE dbt_valid_to IS NULL  -- Chỉ current state
    {% if is_incremental() %}
    AND _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(shipment_id))))) AS shipment_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(warehouse_id))))) AS warehouse_sk,
    _source_system,
    shipment_id AS natural_shipment_id,
    order_id AS natural_order_id,
    warehouse_id AS natural_warehouse_id,
    toUInt32(toYYYYMMDD(shipment_date)) AS date_id,
    trim(carrier) AS carrier,
    trim(shipment_status) AS shipment_status,
    shipment_date,
    now() AS _silver_loaded_at
FROM shipments
