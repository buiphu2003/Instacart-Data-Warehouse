-- ============================================================
-- MODEL   : base_ecommerce_order_items
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.order_items (via ClickHouse PostgreSQL engine)
-- TRANSFORMS:
--   • Cast numeric columns to Nullable(Decimal(18,2))
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : Composite business key = (order_id, product_id) — no single-column PK in source
--           Surrogate key sẽ được tạo ở tầng Silver
-- ============================================================

with source as (
    select * from {{ source('ecommerce_postgres', 'order_items') }}
),

renamed as (
    select
        -- Business columns (raw, with safe type cast)
        order_id,
        product_id,
        quantity,
        cast(unit_price as Nullable(Decimal(18,2))) as unit_price,
        cast(subtotal   as Nullable(Decimal(18,2))) as subtotal,

        -- Audit metadata
        'ecommerce_postgres'        as _source_system,
        now()                       as _bronze_loaded_at,
        toDate(now())               as _bronze_load_date

    from source
)

select * from renamed
