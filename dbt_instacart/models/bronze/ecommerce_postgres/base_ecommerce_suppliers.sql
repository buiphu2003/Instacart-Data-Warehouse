with source as (
    select * from {{ source('ecommerce_postgres', 'suppliers') }}
),

renamed as (
    select
        supplier_id,
        supplier_name,
        contact_email,
        contact_phone,
        country,
        now() as _bronze_loaded_at
    from source
)

select * from renamed