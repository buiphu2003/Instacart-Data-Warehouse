with source as (
    select * from {{ source('ecommerce_postgres', 'returns') }}
),

renamed as (
    select
        return_id,
        order_id,
        customer_id,
        cast(return_date as timestamp) as return_date,
        reason as return_reason,
        status as return_status,
        now() as _bronze_loaded_at
    from source
)

select * from renamed