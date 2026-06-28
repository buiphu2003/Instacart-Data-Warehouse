{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='shipment_sk'
) }}

WITH shipments AS (
    SELECT *
    FROM {{ ref('base_ecommerce_shipments') }}
    WHERE dbt_valid_to IS NULL
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
