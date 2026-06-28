{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='event_sk'
) }}

WITH payments_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_payments') }}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(payment_id), '|', toString(dbt_scd_id))))) AS event_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(payment_id))))) AS payment_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    _source_system,
    payment_id AS natural_payment_id,
    order_id AS natural_order_id,
    toUInt32(toYYYYMMDD(payment_created_at)) AS date_id,
    payment_amount,
    trim(payment_method) AS payment_method,
    trim(payment_status) AS payment_status,
    payment_created_at,
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM payments_history
