{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='event_sk',
    unique_key='event_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_orders_history
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_orders (Bronze — SCD2 snapshot data)
-- STRATEGY: incremental — unique_key=event_sk
--           ALL rows (kể cả dbt_valid_to IS NOT NULL) → lưu toàn bộ lịch sử
--           event_sk = MD5(source|order_id|dbt_scd_id) → unique per SCD2 event
--           → mỗi lần status thay đổi, Bronze thêm 1 row mới → Silver append 1 event
-- ============================================================

WITH ecom_orders_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_orders') }}
    {% if is_incremental() %}
    -- Chỉ append events mới từ Bronze kể từ lần Silver chạy trước
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id), '|', toString(dbt_scd_id))))) AS event_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(customer_id))))) AS customer_sk,
    _source_system,
    order_id AS natural_order_id,
    trim(order_status) AS order_status,
    total_amount,
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM ecom_orders_history
