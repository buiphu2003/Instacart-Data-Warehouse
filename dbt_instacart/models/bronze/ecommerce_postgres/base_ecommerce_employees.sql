-- ============================================================
-- MODEL   : base_ecommerce_employees
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.employees (via ClickHouse PostgreSQL engine)
-- STRATEGY: incremental — unique_key=employee_id
--           Filter: updated_at > max(_bronze_loaded_at)
--           updated_at được cập nhật tự động qua trigger trg_employees_updated_at
-- TRANSFORMS:
--   • Minimal rename: email→employee_email
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='employee_id',
    unique_key='employee_id',
    incremental_strategy='delete+insert'
) }}

with source as (
    select * from {{ source('ecommerce_postgres', 'employees') }}
    {% if is_incremental() %}
    -- Macro format watermark thành ISO string tránh type mismatch DateTime>integer
    -- khi ClickHouse push WHERE clause xuống PostgreSQL engine
    where updated_at > {{ get_max_bronze_loaded_at(this) }}
    {% endif %}
),

renamed as (
    select
        -- Business columns (raw, minimal rename)
        employee_id,
        first_name,
        last_name,
        email       as employee_email,
        hire_date,
        warehouse_id,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
