{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='(date_id, payment_method)',
    settings={'allow_nullable_key': 1}
) }}

-- ================================================================
-- MART   : mart_payment_summary
-- PURPOSE: Tổng hợp giao dịch thanh toán theo ngày và phương thức
--          Phục vụ: Finance team, Payment ops, Executive dashboard
-- GRAIN  : 1 row = 1 ngày × 1 phương thức thanh toán
-- SOURCE : fact_payments + dim_date
-- METRICS: GMV, transaction count, success/failure/refund rate, AOV
-- ================================================================

WITH payments AS (
    SELECT
        date_id,
        payment_method,
        payment_status,
        payment_amount
    FROM {{ ref('fact_payments') }}
),

dates AS (
    SELECT
        date_id,
        date,
        year,
        quarter,
        month,
        day_of_month,
        is_weekend
    FROM {{ ref('dim_date') }}
)

SELECT
    d.date_id,
    d.date                                                             AS full_date,
    d.year,
    d.quarter,
    d.month,
    d.day_of_month,
    d.is_weekend,
    p.payment_method,

    -- Volume
    count(*)                                                           AS total_transactions,

    -- GMV (Gross Merchandise Value) — tổng giá trị trước khi trừ refund
    round(sum(p.payment_amount), 2)                                    AS gross_amount,

    -- Net revenue = SUCCESS amount - REFUNDED amount
    round(
        sum(if(p.payment_status = 'SUCCESS',  p.payment_amount, 0))
      - sum(if(p.payment_status = 'REFUNDED', p.payment_amount, 0)),
        2
    )                                                                  AS net_amount,

    round(avg(p.payment_amount), 2)                                    AS avg_transaction_amount,
    round(max(p.payment_amount), 2)                                    AS max_transaction_amount,
    round(min(p.payment_amount), 2)                                    AS min_transaction_amount,

    -- Breakdown by status: count
    countIf(p.payment_status = 'SUCCESS')                              AS success_count,
    countIf(p.payment_status = 'FAILED')                               AS failure_count,
    countIf(p.payment_status = 'REFUNDED')                             AS refund_count,

    -- Breakdown by status: amount
    round(sum(if(p.payment_status = 'SUCCESS',  p.payment_amount, 0)), 2) AS success_amount,
    round(sum(if(p.payment_status = 'FAILED',   p.payment_amount, 0)), 2) AS failed_amount,
    round(sum(if(p.payment_status = 'REFUNDED', p.payment_amount, 0)), 2) AS refund_amount,

    -- Rates (so sánh trực tiếp trên Superset / dashboard)
    round(countIf(p.payment_status = 'SUCCESS')  / nullIf(count(*), 0), 4) AS success_rate,
    round(countIf(p.payment_status = 'FAILED')   / nullIf(count(*), 0), 4) AS failure_rate,
    round(countIf(p.payment_status = 'REFUNDED') / nullIf(count(*), 0), 4) AS refund_rate,

    now()                                                              AS _gold_loaded_at

FROM dates d
INNER JOIN payments p ON d.date_id = p.date_id
GROUP BY
    d.date_id,
    d.date,
    d.year,
    d.quarter,
    d.month,
    d.day_of_month,
    d.is_weekend,
    p.payment_method
