-- ============================================================
-- MODEL   : base_ecommerce_returns
-- LAYER   : Bronze
-- SOURCE  : ecommerce_returns_snapshot (dbt Snapshot — SCD2 of ecommerce.returns)
-- LINEAGE : ecommerce_postgres.returns → [dbt snapshot] → this model
-- TRANSFORMS:
--   • Cast return_date → timestamp
--   • Rename: reason→return_reason, status→return_status
--   • Expose dbt snapshot SCD2 columns (dbt_scd_id, dbt_valid_from/to)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : dbt_scd_id is the unique key for each SCD row.
-- ============================================================

with source as (
    select * from {{ ref('ecommerce_returns_snapshot') }}
),

renamed as (
    select
        -- Business columns (with safe type casts + renames)
        return_id,
        order_id,
        customer_id,
        cast(return_date as timestamp)  as return_date,
        reason                          as return_reason,
        status                          as return_status,

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
