with source as (
    select * from {{ source('instacart_bronze', 'orders') }}
),

renamed as (
    select
        order_id,
        user_id,
        eval_set,
        order_number,
        order_dow as order_day_of_week,
        order_hour_of_day,
        days_since_prior_order,
        now() as _bronze_loaded_at
    from source
)

select * from renamed
