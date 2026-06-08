with source as (
    select * from {{ source('instacart_bronze', 'order_products_train') }}
),

renamed as (
    select
        order_id,
        product_id,
        add_to_cart_order,
        reordered,
        now() as _bronze_loaded_at
    from source
)

select * from renamed
