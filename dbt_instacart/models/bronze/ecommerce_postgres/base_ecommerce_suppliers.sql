-- ============================================================
-- MODEL   : base_ecommerce_suppliers
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.suppliers (via ClickHouse PostgreSQL engine)
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

with source as (
    select * from {{ source('ecommerce_postgres', 'suppliers') }}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        supplier_id,
        supplier_name,
        contact_email,
        contact_phone,
        country,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
