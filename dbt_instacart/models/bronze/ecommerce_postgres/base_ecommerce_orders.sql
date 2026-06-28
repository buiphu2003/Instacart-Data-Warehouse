-- ============================================================
-- MODEL   : base_ecommerce_orders
-- LAYER   : Bronze
-- SOURCE  : ecommerce_orders_snapshot (dbt Snapshot — SCD2 of ecommerce.orders)
-- LINEAGE : ecommerce_postgres.orders → [dbt snapshot] → this model
-- TRANSFORMS:
--   • Cast order_date → timestamp as order_created_at
--   • Cast total_amount → Nullable(Decimal(18,2))
--   • Expose dbt snapshot SCD2 columns (dbt_scd_id, dbt_valid_from/to)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : Reads from snapshot (not directly from source) to preserve SCD2 history.
--           dbt_scd_id is the unique key for each SCD row.
-- ============================================================

with source as (
    select * from {{ ref('ecommerce_orders_snapshot') }}
),

renamed as (
    select
        -- Business columns (with safe type casts)
        order_id,
        customer_id,
        cast(order_date as timestamp)                   as order_created_at,
        status                                          as order_status,
        cast(total_amount as Nullable(Decimal(18,2)))   as total_amount,

        -- SCD2 snapshot columns
        dbt_scd_id,
        dbt_updated_at,
        dbt_valid_from,
        dbt_valid_to,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
