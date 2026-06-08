with source as (
    select * from {{ source('ecommerce_postgres', 'payments') }}
),

renamed as (
    select
        payment_id,
        order_id,
        payment_method,
        cast(amount as Nullable(Decimal(18,2))) as payment_amount,
        cast(payment_date as timestamp) as payment_created_at,
        status as payment_status,
        now() as _bronze_loaded_at
    from source
)

select * from renamed