{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='warehouse_sk'
) }}

WITH warehouses AS (
    SELECT * 
    FROM {{ ref('base_ecommerce_warehouses') }}
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

