-- ============================================================
-- TEST    : assert_bronze_row_count_match
-- PURPOSE : Kiểm tra rằng Bronze models không bị mất rows so với source.
--           Trả về rows nếu có sự chênh lệch → dbt test sẽ FAIL.
-- ============================================================
-- NOTE về SCD2:
--   - orders: Bronze đọc từ SNAPSHOT (có nhiều rows/order_id).
--             So sánh count(*) source với count(DISTINCT dbt_scd_id) Bronze.
--   - customers/products: SCD2 tại nguồn. Bronze = source count.
--   - order_items, order_items không có timestamp riêng.
-- ============================================================

-- ── orders: source rows vs snapshot rows (theo dbt_scd_id) ──────
SELECT
    'orders'                                        AS table_name,
    s.cnt                                           AS source_count,
    m.cnt                                           AS bronze_count,
    s.cnt - m.cnt                                   AS difference,
    'Source vs Bronze snapshot rows'                AS note
FROM
    (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'orders') }}) AS s,
    (SELECT COUNT(DISTINCT dbt_scd_id) AS cnt      FROM {{ ref('base_ecommerce_orders') }})    AS m
WHERE s.cnt > m.cnt  -- Flag only when Bronze has FEWER rows than source

UNION ALL

-- ── order_items: direct 1-to-1 (no SCD) ────────────────────────
SELECT
    'order_items'                                   AS table_name,
    s.cnt                                           AS source_count,
    m.cnt                                           AS bronze_count,
    s.cnt - m.cnt                                   AS difference,
    'Direct source vs Bronze (no SCD)'              AS note
FROM
    (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'order_items') }}) AS s,
    (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_order_items') }})           AS m
WHERE s.cnt != m.cnt

UNION ALL

-- ── customers: SCD2 at source — all rows should match ───────────
SELECT
    'customers'                                     AS table_name,
    s.cnt                                           AS source_count,
    m.cnt                                           AS bronze_count,
    s.cnt - m.cnt                                   AS difference,
    'Source SCD2 rows vs Bronze rows'               AS note
FROM
    (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'customers') }}) AS s,
    (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_customers') }})           AS m
WHERE s.cnt != m.cnt

UNION ALL

-- ── products: SCD2 at source — all rows should match ────────────
SELECT
    'products'                                      AS table_name,
    s.cnt                                           AS source_count,
    m.cnt                                           AS bronze_count,
    s.cnt - m.cnt                                   AS difference,
    'Source SCD2 rows vs Bronze rows'               AS note
FROM
    (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'products') }}) AS s,
    (SELECT COUNT(*) AS cnt FROM {{ ref('base_ecommerce_products') }})           AS m
WHERE s.cnt != m.cnt

UNION ALL

-- ── payments: source rows vs snapshot rows (theo dbt_scd_id) ────
SELECT
    'payments'                                      AS table_name,
    s.cnt                                           AS source_count,
    m.cnt                                           AS bronze_count,
    s.cnt - m.cnt                                   AS difference,
    'Source vs Bronze snapshot rows'                AS note
FROM
    (SELECT COUNT(*) AS cnt FROM {{ source('ecommerce_postgres', 'payments') }}) AS s,
    (SELECT COUNT(DISTINCT dbt_scd_id) AS cnt      FROM {{ ref('base_ecommerce_payments') }})  AS m
WHERE s.cnt > m.cnt
