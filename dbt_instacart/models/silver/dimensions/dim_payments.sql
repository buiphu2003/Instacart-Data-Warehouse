{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='payment_sk'
) }}

WITH payments AS (
    SELECT *
    FROM {{ ref('base_ecommerce_payments') }}
)

SELECT
    lower(hex(MD5(concat('ecommerce-', toString(coalesce(payment_id, 0)))))) AS payment_sk,
    payment_id AS original_payment_id,
    order_id AS original_order_id,
    trim(payment_method) AS payment_method,
    payment_amount,
    payment_created_at,
    trim(payment_status) AS payment_status,
    now() AS _silver_loaded_at
FROM payments
