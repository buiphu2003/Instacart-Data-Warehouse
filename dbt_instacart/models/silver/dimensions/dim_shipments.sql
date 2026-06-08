{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='shipment_sk'
) }}

WITH shipments AS (
    SELECT *
    FROM {{ ref('base_ecommerce_shipments') }}
)

SELECT
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(shipment_id, 0)))))) AS shipment_sk,
    shipment_id AS original_shipment_id,
    order_id AS original_order_id,
    warehouse_id,
    shipment_date,
    trim(carrier) AS carrier,
    trim(shipment_status) AS shipment_status,
    now() AS _silver_loaded_at
FROM shipments
