-- ============================================================
-- TEST    : assert_dim_date_no_gaps
-- PURPOSE : Đảm bảo date dimension không có ngày nào bị bỏ sót
--           trong dải từ 2020-01-01 đến 2029-12-31.
--           Mọi ngày đều phải có record liền kề với ngày tiếp theo.
-- LOGIC   : Nếu query này trả về bất kỳ row nào → TEST FAIL
-- ============================================================

WITH ordered_dates AS (
    SELECT
        date,
        -- Fix ClickHouse: lagInFrame với Date type trả về 1970-01-01 (không phải NULL)
        -- cho dòng đầu tiên. Cast sang Nullable(Date) để buộc trả về NULL thật sự.
        lagInFrame(toNullable(date)) OVER (ORDER BY date) AS prev_date
    FROM {{ ref('dim_date') }}
)

SELECT
    prev_date,
    date,
    dateDiff('day', prev_date, date) AS gap_days
FROM ordered_dates
WHERE
    -- Loại bỏ row đầu tiên (prev_date = NULL thật sự, không phải 1970-01-01)
    prev_date IS NOT NULL
    -- Nếu khoảng cách giữa 2 ngày liền kề > 1 → có gap
    AND dateDiff('day', prev_date, date) > 1
