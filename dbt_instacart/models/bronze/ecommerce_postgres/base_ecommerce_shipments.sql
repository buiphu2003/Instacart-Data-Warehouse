-- ============================================================
-- MODEL   : base_ecommerce_shipments
-- LAYER   : Bronze
-- SOURCE  : ecommerce_shipments_snapshot (dbt Snapshot — SCD2 of ecommerce.shipments)
-- LINEAGE : ecommerce_postgres.shipments → [dbt snapshot] → this model
-- STRATEGY: incremental — unique_key=dbt_scd_id
--           Filter: dbt_updated_at > max(_bronze_loaded_at)
-- TRANSFORMS:
--   • Cast shipment_date → timestamp
--   • Rename: status→shipment_status
--   • Expose dbt snapshot SCD2 columns (dbt_scd_id, dbt_valid_from/to)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='dbt_scd_id',
    unique_key='dbt_scd_id',
    incremental_strategy='delete+insert'
) }}

with source as (
    select * from {{ ref('ecommerce_shipments_snapshot') }}
    {% if is_incremental() %}
    -- Chỉ lấy SCD2 rows được snapshot tạo/cập nhật kể từ lần Bronze load trước
    where dbt_updated_at > (select max(_bronze_loaded_at) from {{ this }})
    {% endif %}
),

renamed as (
    select
        -- Business columns (with safe type casts + renames)
        shipment_id,
        order_id,
        warehouse_id,
        cast(shipment_date as timestamp)    as shipment_date,
        carrier,
        status                              as shipment_status,

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
