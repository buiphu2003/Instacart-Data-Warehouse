{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='payment_sk'
) }}

WITH payments AS (
    SELECT *
    FROM {{ ref('base_ecommerce_payments') }}
    WHERE dbt_valid_to IS NULL
)

SELECT
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
    now() AS _silver_loaded_at
FROM payments
