with source as (
    select * from {{ source('ecommerce_postgres', 'order_items') }}
),

renamed as (
    select
        order_id,
        product_id,
        quantity,
        cast(unit_price as Nullable(Decimal(18,2))) as unit_price,
        cast(subtotal as Nullable(Decimal(18,2))) as subtotal,
        now() as _bronze_loaded_at
    from source
)

select * from renamed