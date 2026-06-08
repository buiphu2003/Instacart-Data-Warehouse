with source as (
    select * from {{ source('ecommerce_postgres', 'shipments') }}
),

renamed as (
    select
        shipment_id,
        order_id,
        warehouse_id,
        cast(shipment_date as timestamp) as shipment_date,
        carrier,
        status as shipment_status,
        now() as _bronze_loaded_at
    from source
)

select * from renamed