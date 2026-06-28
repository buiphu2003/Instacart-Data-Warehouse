-- ============================================================
-- MODEL   : base_instacart_aisles
-- LAYER   : Bronze
-- SOURCE  : instacart_bronze.base_instacart_aisles (ClickHouse — loaded from CSV)
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

{{ config(order_by='tuple()') }}

with source as (
    select * from {{ source('instacart_bronze', 'base_instacart_aisles') }}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        aisle_id,
        aisle_name,

        -- Audit metadata
        'instacart_csv'     as _source_system,
        now()               as _bronze_loaded_at,
        toDate(now())       as _bronze_load_date

    from source
)

select * from renamed
