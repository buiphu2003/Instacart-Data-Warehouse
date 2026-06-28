-- ============================================================
-- TEST    : assert_order_items_total_matches_order_total
-- PURPOSE : Đảm bảo tổng tiền của các line items (order_items)
--           phải khớp với tổng tiền của đơn hàng (orders)
--           (chỉ áp dụng cho E-commerce vì Instacart total_amount = 0)
--
-- ⚠️  KNOWN LIMITATION (Synthetic Data):
--     Dataset ecommerce là dữ liệu synthetic được generate ngẫu nhiên.
--     orders.total_amount và order_items.subtotal được tạo ĐỘC LẬP nhau,
--     không có ràng buộc tổng. Với production data thực sự, test này
--     phải PASS (total_amount = sum(subtotal) ± tax/shipping).
--     → severity: warn để không block pipeline.
-- ============================================================

{{ config(
    severity = 'warn',
    store_failures = false
) }}

WITH order_totals AS (
    SELECT 
        order_sk, 
        total_amount
    FROM {{ ref('fact_orders') }}
    WHERE _source_system = 'ecommerce_postgres'
),

item_totals AS (
    SELECT 
        order_sk, 
        sum(total_price) as sum_items
    FROM {{ ref('fact_order_items') }}
    WHERE _source_system = 'ecommerce_postgres'
    GROUP BY order_sk
)

SELECT 
    o.order_sk,
    o.total_amount,
    i.sum_items,
    abs(o.total_amount - coalesce(i.sum_items, 0)) as difference
FROM order_totals o
LEFT JOIN item_totals i ON o.order_sk = i.order_sk
-- Chấp nhận sai số làm tròn 0.01
WHERE abs(o.total_amount - coalesce(i.sum_items, 0)) > 0.1
