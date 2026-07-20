{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='payment_sk',
    unique_key='payment_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_payments
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_payments (Bronze)
-- STRATEGY: incremental — unique_key=payment_sk (UPSERT current state)
--           dbt_valid_to IS NULL → chỉ lấy trạng thái hiện tại
-- ============================================================

WITH payments AS (
    SELECT *
    FROM {{ ref('base_ecommerce_payments') }}
    WHERE dbt_valid_to IS NULL  -- Chỉ current state
    {% if is_incremental() %}
    AND _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
