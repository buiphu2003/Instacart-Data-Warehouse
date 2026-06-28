{% snapshot ecommerce_payments_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='payment_id',
      strategy='check',
      check_cols=['status', 'amount']
    )
}}

-- Capture SCD2 history for payments.
-- Tracks changes to: status (e.g. PENDING→SUCCESS→REFUNDED) and amount (e.g. partial refund)
SELECT *
FROM {{ source('ecommerce_postgres', 'payments') }}

{% endsnapshot %}
