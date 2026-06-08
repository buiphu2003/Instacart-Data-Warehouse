with source as (
    select * from {{ source('ecommerce_postgres', 'customers') }}
),

renamed as (
    select
        customer_id,
        first_name,
        last_name,
        email as customer_email,
        phone as customer_phone,
        address as customer_address,
        loyalty_tier,
        valid_from,
        valid_to,
        is_current,
        now() as _bronze_loaded_at
    from source
)

select * from renamed