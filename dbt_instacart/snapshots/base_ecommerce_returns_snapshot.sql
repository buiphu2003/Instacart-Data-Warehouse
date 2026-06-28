{% snapshot ecommerce_returns_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='return_id',
      strategy='check',
      check_cols=['status', 'reason']
    )
}}

-- Capture SCD2 history for returns.
-- Tracks changes to: status (e.g. PENDING→APPROVED/REJECTED) and reason (correction)
SELECT *
FROM {{ source('ecommerce_postgres', 'returns') }}

{% endsnapshot %}
