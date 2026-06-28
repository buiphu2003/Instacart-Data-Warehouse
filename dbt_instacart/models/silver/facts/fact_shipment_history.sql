{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='event_sk'
) }}

WITH shipments_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_shipments') }}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(shipment_id), '|', toString(dbt_scd_id))))) AS event_sk,
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
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM shipments_history
