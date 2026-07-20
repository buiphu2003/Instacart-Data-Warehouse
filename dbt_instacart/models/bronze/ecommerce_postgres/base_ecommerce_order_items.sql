-- ============================================================
-- MODEL   : base_ecommerce_order_items
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.order_items (via ClickHouse PostgreSQL engine)
-- STRATEGY: incremental — unique_key=[order_id, product_id]
--           Filter: updated_at > max(_bronze_loaded_at)
--           order_items thực tế là INSERT-only (không bao giờ UPDATE),
--           nhưng dùng updated_at để thống nhất pattern và an toàn nếu có exception
-- TRANSFORMS:
--   • Cast numeric columns to Nullable(Decimal(18,2))
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : Composite business key = (order_id, product_id) — no single-column PK in source
--           Surrogate key sẽ được tạo ở tầng Silver
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by=['order_id', 'product_id'],
    unique_key=['order_id', 'product_id'],
    incremental_strategy='delete+insert',
    settings={'allow_nullable_key': 1}
) }}

with source as (
    select * from {{ source('ecommerce_postgres', 'order_items') }}
    {% if is_incremental() %}
    -- Chỉ lấy order_items có updated_at mới hơn
    -- Macro format watermark thành ISO string tránh type mismatch DateTime>integer
    -- khi ClickHouse push WHERE clause xuống PostgreSQL engine
    where updated_at > {{ get_max_bronze_loaded_at(this) }}
    {% endif %}
),

renamed as (
    select
        -- Business columns (raw, with safe type cast)
        order_id,
        product_id,
        quantity,
        cast(unit_price as Nullable(Decimal(18,2))) as unit_price,
        cast(subtotal   as Nullable(Decimal(18,2))) as subtotal,

        -- Audit metadata
        'ecommerce_postgres'        as _source_system,
        now()                       as _bronze_loaded_at,
        toDate(now())               as _bronze_load_date

    from source
)

select * from renamed
