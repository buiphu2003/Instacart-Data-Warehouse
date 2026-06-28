-- ============================================================
-- MODEL   : base_ecommerce_categories
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.categories (via ClickHouse PostgreSQL engine)
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : Self-referencing hierarchy (parent_category_id)
-- ============================================================

with source as (
    select * from {{ source('ecommerce_postgres', 'categories') }}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        category_id,
        category_name,
        parent_category_id,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
