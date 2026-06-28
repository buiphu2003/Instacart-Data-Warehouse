-- ============================================================
-- MODEL   : base_instacart_orders
-- LAYER   : Bronze
-- SOURCE  : instacart_bronze.base_instacart_orders (ClickHouse — loaded from CSV)
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

with source as (
    select * from {{ source('instacart_bronze', 'base_instacart_orders') }}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        order_id,
        user_id,
        eval_set,
        order_number,
        order_day_of_week,
        order_hour_of_day,
        days_since_prior_order,

        -- Audit metadata
        'instacart_csv'     as _source_system,
        now()               as _bronze_loaded_at,
        toDate(now())       as _bronze_load_date

    from source
)

select * from renamed
