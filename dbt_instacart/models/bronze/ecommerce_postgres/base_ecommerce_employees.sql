with source as (
    select * from {{ source('ecommerce_postgres', 'employees') }}
),

renamed as (
    select
        employee_id,
        first_name,
        last_name,
        email as employee_email,
        hire_date, 
        warehouse_id,
        now() as _bronze_loaded_at
    from source
)

select * from renamed