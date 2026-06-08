with source as (
    select * from {{ source('ecommerce_postgres', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        cast(order_date as timestamp) as order_created_at,
        status as order_status,
        cast(total_amount as Nullable(Decimal(18,2))) as total_amount,
        now() as _bronze_loaded_at
    from source
)

select * from renamed