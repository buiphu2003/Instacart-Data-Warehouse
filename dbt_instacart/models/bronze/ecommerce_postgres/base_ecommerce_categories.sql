-- ============================================================
-- MODEL   : base_ecommerce_categories
-- LAYER   : Bronze
-- SOURCE  : ecommerce_postgres.ecommerce.categories (via ClickHouse PostgreSQL engine)
-- STRATEGY: incremental — unique_key=category_id
--           Filter: updated_at > max(_bronze_loaded_at)
--           Reference data: ít thay đổi nhưng vẫn có thể update category_name
-- TRANSFORMS:
--   • Select raw columns as-is (no business logic)
--   • Add audit metadata: _source_system, _bronze_loaded_at, _bronze_load_date
-- NOTE    : Self-referencing hierarchy (parent_category_id)
-- ============================================================

{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree()',
    order_by='category_id',
    unique_key='category_id',
    incremental_strategy='delete+insert'
) }}

with source as (
    select * from {{ source('ecommerce_postgres', 'categories') }}
    {% if is_incremental() %}
    -- Macro format watermark thành ISO string tránh type mismatch DateTime>integer
    -- khi ClickHouse push WHERE clause xuống PostgreSQL engine
    where updated_at > {{ get_max_bronze_loaded_at(this) }}
    {% endif %}
),

renamed as (
    select
        -- Business columns (raw, no transform)
        category_id,
        category_name,
        parent_category_id,

        -- Audit metadata
        'ecommerce_postgres'    as _source_system,
        now()                   as _bronze_loaded_at,
        toDate(now())           as _bronze_load_date

    from source
)

select * from renamed
