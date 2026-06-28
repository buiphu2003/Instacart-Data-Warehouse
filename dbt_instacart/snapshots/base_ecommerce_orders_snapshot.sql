{% snapshot ecommerce_orders_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='order_id',
      strategy='check',
      check_cols=['status', 'total_amount']
    )
}}

-- Capture SCD2 history for orders.
-- Tracks changes to: status (e.g. PENDING→SHIPPED) and total_amount (e.g. price adjustments)
SELECT *
FROM {{ source('ecommerce_postgres', 'orders') }}

{% endsnapshot %}
