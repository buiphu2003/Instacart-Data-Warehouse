
{#
  Thay thế dbt_utils.mutually_exclusive_ranges cho ClickHouse.

  ClickHouse KHÔNG hỗ trợ hàm lead() theo cú pháp SQL chuẩn.
  Phải dùng leadInFrame() với mệnh đề ROWS BETWEEN ... FOLLOWING tường minh.

  Tham số:
    - lower_bound_column : tên cột cận dưới (ví dụ: valid_from)
    - upper_bound_column : tên cột cận trên (ví dụ: valid_to)
    - partition_by       : tên cột partition (ví dụ: original_order_id) [tuỳ chọn]
    - gaps              : 'allowed' (mặc định) | 'not_allowed' | 'required'
#}
{% test mutually_exclusive_ranges_ch(
    model,
    lower_bound_column,
    upper_bound_column,
    partition_by=None,
    gaps='allowed'
) %}

with window_functions as (

    select
        {% if partition_by %}
        {{ partition_by }} as partition_by_col,
        {% endif %}

        {{ lower_bound_column }} as lower_bound,
        {{ upper_bound_column }} as upper_bound,

        -- leadInFrame() là hàm tương đương lead() trong ClickHouse.
        -- Phải chỉ định ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
        -- để ClickHouse biết đây là window frame, không phải aggregate.
        leadInFrame({{ lower_bound_column }}) OVER (
            {% if partition_by %}PARTITION BY {{ partition_by }}{% endif %}
            ORDER BY {{ lower_bound_column }} ASC, {{ upper_bound_column }} ASC
            ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
        ) as next_lower_bound,

        row_number() OVER (
            {% if partition_by %}PARTITION BY {{ partition_by }}{% endif %}
            ORDER BY {{ lower_bound_column }} DESC, {{ upper_bound_column }} DESC
        ) = 1 as is_last_record

    from {{ model }}

    where {{ lower_bound_column }} is not null
      and {{ upper_bound_column }} is not null

    {% if gaps == 'not_allowed' %}
      -- Không cho phép khoảng trống: loại bỏ các range rỗng (lower = upper)
      and {{ lower_bound_column }} != {{ upper_bound_column }}
    {% endif %}

),

calc as (

    select
        *,

        -- Điều kiện 1: lower_bound phải < upper_bound (range hợp lệ)
        coalesce(
            lower_bound < upper_bound,
            false
        ) as is_not_inversed,

        -- Điều kiện 2: upper_bound <= next_lower_bound (không overlap)
        -- is_last_record = true → record cuối, next_lower_bound = 0 (default leadInFrame)
        -- nên dùng is_last_record thay vì kiểm tra NULL
        coalesce(
            upper_bound <= next_lower_bound,
            toUInt8(is_last_record),
            0
        ) as is_not_overlapping

    from window_functions

),

validation_errors as (

    select *
    from calc
    where not (is_not_inversed and is_not_overlapping)

)

select * from validation_errors

{% endtest %}
