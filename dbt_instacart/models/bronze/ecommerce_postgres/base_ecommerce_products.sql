-- ============================================================
-- MODEL   : base_ecommerce_products
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.products (via ClickHouse PostgreSQL engine)
-- TRANSFORMS:
--   • Cast price → Nullable(Decimal(18,2))
--   • SCD Type 2 preserved from source (valid_from, valid_to, is_current)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : No single PK on product_id due to SCD2 multi-row per product
-- ============================================================

with source as (
    select * from {{ source('ecommerce_postgres', 'products') }}
),

renamed as (
    select
        -- Business columns (with safe type cast)
        product_id,
        product_name,
        category_id,
        supplier_id,
        cast(price as Nullable(Decimal(18,2))) as price,
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
