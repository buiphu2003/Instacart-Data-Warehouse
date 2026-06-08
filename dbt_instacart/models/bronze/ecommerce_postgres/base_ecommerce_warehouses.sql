with source as (
    select * from {{ source('ecommerce_postgres', 'warehouses') }}
),

renamed as (
    select
        warehouse_id,
        warehouse_name,
        location,
        capacity,
        now() as _bronze_loaded_at
    from source
)

select * from renamed