with source as (
    select * from {{ source('instacart_bronze', 'aisles') }}
),

renamed as (
    select
        aisle_id,
        aisle as aisle_name,
        now() as _bronze_loaded_at
    from source
)

select * from renamed
