-- ============================================================
-- MODEL   : base_ecommerce_warehouses
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.warehouses (via ClickHouse PostgreSQL engine)
-- STRATEGY: incremental — unique_key=warehouse_id
--           Filter: updated_at > max(_bronze_loaded_at)
--           Reference data: ít thay đổi nhưng vẫn có thể update capacity, location
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='warehouse_id',
    unique_key='warehouse_id',
    incremental_strategy='delete+insert'
) }}

with source as (
    select * from {{ source('ecommerce_postgres', 'warehouses') }}
    {% if is_incremental() %}
    -- Macro format watermark thành ISO string tránh type mismatch DateTime>integer
    -- khi ClickHouse push WHERE clause xuống PostgreSQL engine
    where updated_at > {{ get_max_bronze_loaded_at(this) }}
    {% endif %}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        warehouse_id,
        warehouse_name,
        location,
        capacity,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
