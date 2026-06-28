{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='event_sk'
) }}

WITH ecom_orders_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_orders') }}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id), '|', toString(dbt_scd_id))))) AS event_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    _source_system,
    order_id AS original_order_id,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(customer_id))))) AS customer_sk,
    trim(order_status) AS order_status,
    total_amount,
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM ecom_orders_history
