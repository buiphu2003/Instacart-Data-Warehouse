-- ============================================================
-- MODEL   : base_ecommerce_products
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.products (via ClickHouse PostgreSQL engine)
-- STRATEGY: incremental — unique_key=product_id
--           Filter: updated_at > max(_bronze_loaded_at)
--           updated_at được cập nhật tự động qua trigger trg_products_updated_at
--           khi bất kỳ column nào của product bị UPDATE (VD: price thay đổi)
-- TRANSFORMS:
--   • Cast price → Nullable(Decimal(18,2))
--   • SCD1 source: 1 row duy nhất / product, overwrite khi thay đổi
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='product_id',
    unique_key='product_id',
    incremental_strategy='delete+insert'
) }}

with source as (
    select * from {{ source('ecommerce_postgres', 'products') }}
    {% if is_incremental() %}
    -- Macro format watermark thành ISO string tránh type mismatch DateTime>integer
    -- khi ClickHouse push WHERE clause xuống PostgreSQL engine
    where updated_at > {{ get_max_bronze_loaded_at(this) }}
    {% endif %}
),

renamed as (
    select
        -- Business columns (with safe type cast)
        product_id,
        product_name,
        category_id,
        supplier_id,
        cast(price as Nullable(Decimal(18,2))) as price,
        valid_from,
        valid_to,
        cast(is_current as String) as is_current,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
