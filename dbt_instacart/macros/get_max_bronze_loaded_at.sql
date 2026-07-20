-- ============================================================
-- MACRO : get_max_bronze_loaded_at
-- MỤC ĐÍCH: Lấy watermark từ Bronze table và format thành chuỗi
--           ISO timestamp ('YYYY-MM-DD HH:MM:SS') mà PostgreSQL
--           engine có thể parse khi ClickHouse push WHERE clause.
--
-- VẤN ĐỀ gốc rễ:
--   ClickHouse DateTime → PostgreSQL bị serialize thành Unix integer
--   PostgreSQL báo lỗi: "operator does not exist: timestamp > integer"
--
-- CÁCH FIX:
--   Dùng run_query() để lấy max(_bronze_loaded_at) từ ClickHouse,
--   format thành chuỗi '%Y-%m-%d %H:%M:%S', nhúng trực tiếp vào SQL
--   → PostgreSQL nhận được: WHERE updated_at > '2026-06-30 09:34:38'
--   → PostgreSQL tự cast string → timestamp ✅
--
-- CÁCH DÙNG trong model:
--   {% if is_incremental() %}
--   where updated_at > {{ get_max_bronze_loaded_at(this) }}
--   {% endif %}
-- ============================================================

{% macro get_max_bronze_loaded_at(this_table) %}
    {%- if execute -%}
        {%- set query -%}
            SELECT formatDateTime(
                coalesce(max(_bronze_loaded_at), toDateTime('2000-01-01 00:00:00')),
                '%Y-%m-%d %H:%i:%S'
            )
            FROM {{ this_table }}
        {%- endset -%}
        {%- set result = run_query(query) -%}
        {{- return("'" ~ result.columns[0].values()[0] ~ "'") -}}
    {%- else -%}
        {{- return("'2000-01-01 00:00:00'") -}}
    {%- endif -%}
{% endmacro %}
