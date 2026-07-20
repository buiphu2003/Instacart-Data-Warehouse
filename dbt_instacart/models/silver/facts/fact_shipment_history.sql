{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='event_sk',
    unique_key='event_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_shipment_history
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_shipments (Bronze — SCD2 snapshot data)
-- STRATEGY: incremental — unique_key=event_sk (append SCD2 events)
-- ============================================================

WITH ecom_shipments_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_shipments') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(shipment_id), '|', toString(dbt_scd_id))))) AS event_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(shipment_id))))) AS shipment_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(warehouse_id))))) AS warehouse_sk,
    _source_system,
    shipment_id AS natural_shipment_id,
    trim(carrier) AS carrier,
    trim(shipment_status) AS shipment_status,
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM ecom_shipments_history
