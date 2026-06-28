-- ============================================================
-- MODEL   : base_instacart_order_products_train
-- LAYER   : Bronze
-- SOURCE  : instacart_bronze.base_instacart_order_products_train (ClickHouse — loaded from CSV)
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : Composite business key = (order_id, product_id)
-- ============================================================

with source as (
    select * from {{ source('instacart_bronze', 'base_instacart_order_products_train') }}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        order_id,
        product_id,
        add_to_cart_order,
        reordered,

        -- Audit metadata
        'instacart_csv'     as _source_system,
        now()               as _bronze_loaded_at,
        toDate(now())       as _bronze_load_date

    from source
)

select * from renamed
