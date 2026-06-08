with source as (
    select * from {{ source('ecommerce_postgres', 'products') }}
),

renamed as (
    select
        product_id,
        product_name,
        category_id,
        supplier_id,
        cast(price as Nullable(Decimal(18,2))) as price,
        valid_from,
        valid_to,
        is_current,
        now() as _bronze_loaded_at
    from source
)

select * from renamed