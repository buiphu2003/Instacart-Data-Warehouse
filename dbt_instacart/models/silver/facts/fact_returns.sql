{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='return_sk'
) }}

WITH returns AS (
    SELECT *
    FROM {{ ref('base_ecommerce_returns') }}
    WHERE dbt_valid_to IS NULL
)

SELECT
    lower(hex(MD5(concat(toString(_source_system), '|', toString(return_id))))) AS return_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(order_id))))) AS order_sk,
    lower(hex(MD5(concat(toString(_source_system), '|', toString(customer_id))))) AS customer_sk,
    _source_system,
    return_id AS natural_return_id,
    order_id AS natural_order_id,
    toUInt32(toYYYYMMDD(return_date)) AS date_id,
    trim(return_reason) AS return_reason,
    trim(return_status) AS return_status,
    return_date,
    now() AS _silver_loaded_at
FROM returns
