{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='event_sk'
) }}

WITH ecom_returns_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_returns') }}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(return_id), '|', toString(dbt_scd_id))))) AS event_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(return_id))))) AS return_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(customer_id))))) AS customer_sk,
    _source_system,
    return_id AS natural_return_id,
    order_id AS natural_order_id,
    trim(return_reason) AS return_reason,
    trim(return_status) AS return_status,
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM ecom_returns_history
