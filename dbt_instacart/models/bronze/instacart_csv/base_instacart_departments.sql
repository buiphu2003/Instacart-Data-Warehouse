with source as (
    select * from {{ source('instacart_bronze', 'departments') }}
),

renamed as (
    select
        department_id,
        department as department_name,
        now() as _bronze_loaded_at
    from source
)

select * from renamed
