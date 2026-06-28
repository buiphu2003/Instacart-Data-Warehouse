{% snapshot ecommerce_shipments_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='shipment_id',
      strategy='check',
      check_cols=['status', 'carrier', 'warehouse_id']
    )
}}

-- Capture SCD2 history for shipments.
-- Tracks changes to: status (e.g. IN_TRANSIT→DELIVERED), carrier (re-routing), warehouse_id (transfer)
SELECT *
FROM {{ source('ecommerce_postgres', 'shipments') }}

{% endsnapshot %}
