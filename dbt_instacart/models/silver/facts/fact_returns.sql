{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='return_sk',
    unique_key='return_sk',
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

-- ============================================================
-- MODEL   : fact_returns
-- LAYER   : Silver
-- SOURCE  : base_ecommerce_returns (Bronze)
-- STRATEGY: incremental — unique_key=return_sk (UPSERT current state)
--           dbt_valid_to IS NULL → chỉ lấy trạng thái hiện tại
-- ============================================================

WITH returns AS (
    SELECT *
    FROM {{ ref('base_ecommerce_returns') }}
    WHERE dbt_valid_to IS NULL  -- Chỉ current state
    {% if is_incremental() %}
    AND _bronze_loaded_at > (SELECT max(_silver_loaded_at) FROM {{ this }})
    {% endif %}
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
