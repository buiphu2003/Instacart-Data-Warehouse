-- ============================================================
-- MODEL   : base_ecommerce_payments
-- LAYER   : Bronze
-- SOURCE  : ecommerce_payments_snapshot (dbt Snapshot — SCD2 of ecommerce.payments)
-- LINEAGE : ecommerce_postgres.payments → [dbt snapshot] → this model
-- TRANSFORMS:
--   • Cast payment_date → timestamp as payment_created_at
--   • Cast amount → Nullable(Decimal(18,2)) as payment_amount
--   • Expose dbt snapshot SCD2 columns (dbt_scd_id, dbt_valid_from/to)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : dbt_scd_id is the unique key for each SCD row.
-- ============================================================

with source as (
    select * from {{ ref('ecommerce_payments_snapshot') }}
),

renamed as (
    select
        -- Business columns (with safe type casts)
        payment_id,
        order_id,
        payment_method,
        cast(amount        as Nullable(Decimal(18,2)))  as payment_amount,
        cast(payment_date  as timestamp)                as payment_created_at,
        status                                          as payment_status,

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
