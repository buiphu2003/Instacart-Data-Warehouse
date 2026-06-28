{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='(year, month, category_name)',
    settings={'allow_nullable_key': 1}
) }}

-- ================================================================
-- MART   : mart_sales_by_category
-- PURPOSE: Doanh số bán hàng theo danh mục sản phẩm và thời gian
--          Phục vụ: Category Managers, Merchandising, Seasonal planning
-- GRAIN  : 1 row = 1 category × 1 năm × 1 tháng
-- SOURCE : fact_order_items + fact_orders + dim_products + dim_date
--          + fact_returns (để tính return rate theo category)
-- NOTE   : Ecommerce only — Instacart không có ngày tuyệt đối (date_id=0)
-- ================================================================

WITH order_items AS (
    SELECT
        oi.order_sk,
        oi.product_sk,
        oi.quantity,
        coalesce(oi.total_price, 0) AS total_price
    FROM {{ ref('fact_order_items') }} oi
    WHERE oi._source_system = 'ecommerce_postgres'
),

orders AS (
    SELECT order_sk, date_id
    FROM {{ ref('fact_orders') }}
    WHERE _source_system = 'ecommerce_postgres'
      AND date_id > 0  -- loại trừ records không có ngày (date_id=0 dành cho Instacart)
),

dates AS (
    SELECT date_id, year, quarter, month
    FROM {{ ref('dim_date') }}
),

products AS (
    SELECT product_sk, category_name, sub_category_name, supplier_name
    FROM {{ ref('dim_products') }}
    WHERE _source_system = 'ecommerce_postgres'
),

-- Các đơn hàng đã được APPROVED return (cấp độ order, không phải product)
returned_orders AS (
    SELECT DISTINCT order_sk
    FROM {{ ref('fact_returns') }}
    WHERE return_status = 'APPROVED'
),

-- Join tất cả chiều lại, đánh dấu từng item có bị return không
base AS (
    SELECT
        p.category_name,
        p.sub_category_name,
        d.year,
        d.quarter,
        d.month,
        -- Đổi tên thành item_order_sk để tránh conflict với các CTE khác
        -- cũng có column tên order_sk (order_items, orders, returned_orders)
        oi.order_sk   AS item_order_sk,
        oi.quantity,
        oi.total_price,
        if(ro.order_sk IS NOT NULL, 1, 0) AS is_in_returned_order
    FROM order_items oi
    INNER JOIN orders o      ON oi.order_sk   = o.order_sk
    INNER JOIN dates d       ON o.date_id      = d.date_id
    INNER JOIN products p    ON oi.product_sk  = p.product_sk
    LEFT JOIN returned_orders ro ON oi.order_sk = ro.order_sk
)

SELECT
    category_name,
    sub_category_name,
    year,
    quarter,
    month,

    -- Volume
    -- uniqExact = ClickHouse native cho countDistinct (chính xác 100%)
    uniqExact(item_order_sk)                                                  AS total_orders,
    sum(quantity)                                                             AS total_units_sold,

    -- Revenue
    round(sum(total_price), 2)                                                AS total_revenue,
    round(sum(total_price) / nullIf(toFloat64(uniqExact(item_order_sk)), 0), 2) AS avg_order_value,
    round(sum(total_price) / nullIf(sum(quantity), 0), 2)                    AS avg_unit_price,

    -- Returns (uniqExactIf = ClickHouse native cho countDistinctIf)
    uniqExactIf(item_order_sk, is_in_returned_order = 1)                      AS returned_orders,
    round(
        toFloat64(uniqExactIf(item_order_sk, is_in_returned_order = 1))
        / nullIf(toFloat64(uniqExact(item_order_sk)), 0),
        4
    )                                                                         AS return_rate,

    now()                                                                AS _gold_loaded_at

FROM base
GROUP BY
    category_name,
    sub_category_name,
    year,
    quarter,
    month
