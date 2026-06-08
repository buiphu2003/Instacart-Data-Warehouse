with source as (
    select * from {{ source('instacart_bronze', 'products') }}
),

renamed as (
    select
        product_id,
        product_name,
        aisle_id,
        department_id,
        now() as _bronze_loaded_at
    from source
)

select * from renamed
