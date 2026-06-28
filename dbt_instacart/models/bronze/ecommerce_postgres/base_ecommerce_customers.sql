-- ============================================================
-- MODEL   : base_ecommerce_customers
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.customers (via ClickHouse PostgreSQL engine)
-- TRANSFORMS:
--   • Minimal renames: email→customer_email, phone→customer_phone,
--     address→customer_address
--   • SCD Type 2 preserved from source (valid_from, valid_to, is_current)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : No single PK on customer_id due to SCD2 multi-row per customer
-- ============================================================

with source as (
    select * from {{ source('ecommerce_postgres', 'customers') }}
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
