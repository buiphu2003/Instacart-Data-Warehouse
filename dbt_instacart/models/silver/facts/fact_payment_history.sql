{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='event_sk',
    unique_key='event_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_payment_history
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_payments (Bronze — SCD2 snapshot data)
-- STRATEGY: incremental — unique_key=event_sk (append SCD2 events)
-- ============================================================

WITH ecom_payments_history AS (
    SELECT *
    FROM {{ ref('base_ecommerce_payments') }}
    {% if is_incremental() %}
    WHERE _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(payment_id), '|', toString(dbt_scd_id))))) AS event_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(payment_id))))) AS payment_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    _source_system,
    payment_id AS natural_payment_id,
    payment_amount,
    trim(payment_method) AS payment_method,
    trim(payment_status) AS payment_status,
    CAST(dbt_valid_from AS Nullable(DateTime)) AS valid_from,
    CAST(coalesce(dbt_valid_to, toDateTime('9999-12-31 23:59:59')) AS Nullable(DateTime)) AS valid_to,
    if(dbt_valid_to IS NULL, 1, 0) AS is_current_status,
    now() AS _silver_loaded_at
FROM ecom_payments_history
