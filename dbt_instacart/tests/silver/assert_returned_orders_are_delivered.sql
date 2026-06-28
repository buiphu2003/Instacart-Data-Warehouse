-- ============================================================
-- TEST    : assert_returned_orders_are_delivered
-- PURPOSE : Đảm bảo một đơn hàng chỉ có thể bị hoàn trả (Return)
--           khi trạng thái của nó đã là 'DELIVERED'.
-- ============================================================

SELECT 
    r.return_sk,
    r.order_sk,
    o.order_status
FROM {{ ref('fact_returns') }} r
JOIN {{ ref('fact_orders') }} o ON r.order_sk = o.order_sk
WHERE o.order_status != 'DELIVERED'
