-- ============================================================
-- MODEL   : base_ecommerce_customers
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.customers (via ClickHouse PostgreSQL engine)
-- STRATEGY: incremental — unique_key=customer_id
--           Filter: updated_at > max(_bronze_loaded_at)
--           updated_at được cập nhật tự động qua trigger trg_customers_updated_at
--           khi bất kỳ column nào của customer bị UPDATE (VD: loyalty_tier thay đổi)
-- TRANSFORMS:
--   • Minimal renames: email→customer_email, phone→customer_phone,
--     address→customer_address
--   • SCD1 source: 1 row duy nhất / customer, overwrite khi thay đổi
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='customer_id',
    unique_key='customer_id',
    incremental_strategy='delete+insert'
) }}

with source as (
    select * from {{ source('ecommerce_postgres', 'customers') }}
    {% if is_incremental() %}
    -- Macro format watermark thành ISO string tránh type mismatch DateTime>integer
    -- khi ClickHouse push WHERE clause xuống PostgreSQL engine
    where updated_at > {{ get_max_bronze_loaded_at(this) }}
    {% endif %}
),

renamed as (
    select
        -- Business columns (raw, minimal rename)
        customer_id,
        first_name,
        last_name,
        email       as customer_email,
        phone       as customer_phone,
        address     as customer_address,
        loyalty_tier,
        valid_from,
        valid_to,
        cast(is_current as String) as is_current,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
