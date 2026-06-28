{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='product_sk'
) }}

-- ================================================================
-- MART   : mart_return_by_product
-- PURPOSE: Phân tích tỷ lệ hoàn trả theo từng sản phẩm và nhà cung cấp
--          Phục vụ: Product quality team, Procurement, Buyer team
-- GRAIN  : 1 row = 1 sản phẩm (ecommerce)
-- SOURCE : fact_returns + fact_order_items + dim_products
--
-- THIẾT KẾ QUAN TRỌNG:
--   fact_returns ở grain ORDER (không phải product). Một return order có thể
--   chứa nhiều sản phẩm → ta gán return cho TẤT CẢ sản phẩm trong đơn đó.
--   return_rate = (đơn có return VÀ chứa SP này) / (tổng đơn chứa SP này)
-- ================================================================

WITH products AS (
    SELECT
        product_sk,
        product_name,
        category_name,
        sub_category_name,
        supplier_name,
        current_price
    FROM {{ ref('dim_products') }}
    WHERE _source_system = 'ecommerce_postgres'
),

-- Tổng bán theo sản phẩm (ecommerce)
sales AS (
    SELECT
        product_sk,
        countDistinct(order_sk)                    AS total_orders,
        sum(quantity)                              AS total_units_sold,
        round(sum(coalesce(total_price, 0)), 2)    AS total_revenue,
        round(avg(coalesce(unit_price,  0)), 2)    AS avg_selling_price
    FROM {{ ref('fact_order_items') }}
    WHERE _source_system = 'ecommerce_postgres'
    GROUP BY product_sk
),

-- Các đơn hàng APPROVED return, cùng lý do
approved_returns AS (
    SELECT
        order_sk,
        return_reason
    FROM {{ ref('fact_returns') }}
    WHERE return_status = 'APPROVED'
),

-- Gắn return xuống cấp product:
--   1 return order → tất cả sản phẩm trong đơn đó đều được gán 1 return event
-- Đây là xấp xỉ hợp lý vì nguồn không có return_item level
return_by_reason AS (
    SELECT
        oi.product_sk,
        r.return_reason,
        count(DISTINCT r.order_sk) AS return_count
    FROM approved_returns r
    INNER JOIN {{ ref('fact_order_items') }} oi
        ON r.order_sk = oi.order_sk
       AND oi._source_system = 'ecommerce_postgres'
    GROUP BY oi.product_sk, r.return_reason
),

-- Tổng hợp theo sản phẩm + lấy lý do return phổ biến nhất
return_summary AS (
    SELECT
        product_sk,
        sum(return_count)                            AS total_return_orders,
        -- argMax(value, max_by_column): trả về return_reason có return_count lớn nhất
        argMax(return_reason, return_count)          AS top_return_reason,
        max(return_count)                            AS top_reason_count
    FROM return_by_reason
    GROUP BY product_sk
)

SELECT
    assumeNotNull(p.product_sk)                          AS product_sk,
    p.product_name,
    p.category_name,
    p.sub_category_name,
    p.supplier_name,
    coalesce(p.current_price, 0)                         AS current_price,

    -- Sales metrics
    coalesce(s.total_orders,     0)                      AS total_orders,
    coalesce(s.total_units_sold, 0)                      AS total_units_sold,
    coalesce(s.total_revenue,    0)                      AS total_revenue,
    coalesce(s.avg_selling_price, 0)                     AS avg_selling_price,

    -- Return metrics
    coalesce(rs.total_return_orders, 0)                  AS total_return_orders,

    -- return_rate = bao nhiêu % đơn hàng chứa SP này bị return
    round(
        coalesce(rs.total_return_orders, 0)
        / nullIf(coalesce(s.total_orders, 0), 0),
        4
    )                                                    AS return_rate,

    -- Lý do return phổ biến nhất (ClickHouse argMax)
    coalesce(rs.top_return_reason, 'N/A')                AS top_return_reason,
    coalesce(rs.top_reason_count,  0)                    AS top_reason_count,

    now()                                                AS _gold_loaded_at

FROM products p
LEFT JOIN sales s          ON p.product_sk = s.product_sk
LEFT JOIN return_summary rs ON p.product_sk = rs.product_sk
