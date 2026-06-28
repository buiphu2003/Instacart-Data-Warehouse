{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='order_sk',
    settings={'allow_nullable_key': 1}
) }}

WITH order_history AS (
    SELECT * 
    FROM {{ ref('fact_orders_history') }}
),
pivoted AS (
    SELECT
        order_sk,
        original_order_id,
        _source_system,
        MIN(if(order_status = 'PENDING', valid_from, CAST(NULL AS Nullable(DateTime)))) AS pending_at,
        MIN(if(order_status = 'PROCESSING', valid_from, CAST(NULL AS Nullable(DateTime)))) AS processing_at,
        MIN(if(order_status = 'SHIPPED', valid_from, CAST(NULL AS Nullable(DateTime)))) AS shipped_at,
        MIN(if(order_status = 'DELIVERED', valid_from, CAST(NULL AS Nullable(DateTime)))) AS delivered_at
    FROM order_history
    GROUP BY order_sk, original_order_id, _source_system
),
shipments AS (
    SELECT order_sk, warehouse_sk
    FROM {{ ref('fact_shipments') }}
),
warehouses AS (
    SELECT warehouse_sk, warehouse_name
    FROM {{ ref('dim_warehouses') }}
)

SELECT
    p.order_sk AS order_sk,
    p.original_order_id AS natural_order_id,
    p._source_system,
    
    -- Mốc thời gian
    p.pending_at,
    p.processing_at,
    p.shipped_at,
    p.delivered_at,
    
    -- Tính toán Lead Time (số giờ)
    dateDiff('hour', p.pending_at, p.processing_at) AS hours_to_process,
    dateDiff('hour', p.processing_at, p.shipped_at) AS hours_to_ship,
    dateDiff('hour', p.shipped_at, p.delivered_at) AS hours_to_deliver,
    dateDiff('hour', p.pending_at, p.delivered_at) AS total_fulfillment_hours,
    
    -- Thông tin kho để xem nút thắt
    w.warehouse_sk,
    coalesce(w.warehouse_name, 'Unknown') AS warehouse_name,
    
    now() AS _gold_loaded_at
FROM pivoted p
LEFT JOIN shipments s ON p.order_sk = s.order_sk
LEFT JOIN warehouses w ON s.warehouse_sk = w.warehouse_sk
WHERE p.pending_at IS NOT NULL 
  AND p._source_system = 'ecommerce_postgres'
