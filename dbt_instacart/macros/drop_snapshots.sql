{% macro drop_snapshots() %}
    {% set drop_queries = [
        "DROP TABLE IF EXISTS snapshots.ecommerce_orders_snapshot",
        "DROP TABLE IF EXISTS snapshots.ecommerce_payments_snapshot",
        "DROP TABLE IF EXISTS snapshots.ecommerce_returns_snapshot",
        "DROP TABLE IF EXISTS snapshots.ecommerce_shipments_snapshot"
    ] %}
    
    {% for query in drop_queries %}
        {% do run_query(query) %}
        {{ log("Executed: " ~ query, info=True) }}
    {% endfor %}
    
    {{ log("All snapshot tables have been dropped successfully.", info=True) }}
{% endmacro %}
