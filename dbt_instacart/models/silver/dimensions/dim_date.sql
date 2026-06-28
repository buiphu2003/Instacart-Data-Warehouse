{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='date_id'
) }}

WITH date_spine AS (
    SELECT
        toDate('2020-01-01') + number AS date_day
    FROM system.numbers
    WHERE number < dateDiff(
        'day',
        toDate('2020-01-01'),
        toDate('2030-01-01')
    )
)

SELECT
    toUInt32(toYYYYMMDD(date_day)) AS date_id,
    date_day AS date,
    toYear(date_day) AS year,
    toQuarter(date_day) AS quarter,
    toMonth(date_day) AS month,
    toDayOfMonth(date_day) AS day_of_month,
    toDayOfWeek(date_day) AS day_of_week,
    toDayOfYear(date_day) AS day_of_year,
    if(toDayOfWeek(date_day) IN (6, 7), 1, 0) AS is_weekend,
    now() AS _silver_loaded_at
FROM date_spine
