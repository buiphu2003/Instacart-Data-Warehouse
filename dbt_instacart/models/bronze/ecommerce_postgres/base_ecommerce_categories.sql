with source as (
    select * from {{ source('ecommerce_postgres', 'categories') }}
),

renamed as (
    select
        category_id,
        category_name,
        parent_category_id,
        now() as _bronze_loaded_at
    from source
)

select * from renamed