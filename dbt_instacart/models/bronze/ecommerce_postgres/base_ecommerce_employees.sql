-- ============================================================
-- MODEL   : base_ecommerce_employees
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.employees (via ClickHouse PostgreSQL engine)
-- TRANSFORMS:
--   • Minimal rename: email→employee_email
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

with source as (
    select * from {{ source('ecommerce_postgres', 'employees') }}
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
