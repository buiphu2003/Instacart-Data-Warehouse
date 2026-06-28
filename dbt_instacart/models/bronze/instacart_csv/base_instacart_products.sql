-- ============================================================
-- MODEL   : base_instacart_products
-- LAYER   : Bronze
-- SOURCE  : instacart_bronze.base_instacart_products (ClickHouse — loaded from CSV)
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

with source as (
    select * from {{ source('instacart_bronze', 'base_instacart_products') }}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        product_id,
        product_name,
        aisle_id,
        department_id,

        -- Audit metadata
        'instacart_csv'     as _source_system,
        now()               as _bronze_loaded_at,
        toDate(now())       as _bronze_load_date

    from source
)

select * from renamed
