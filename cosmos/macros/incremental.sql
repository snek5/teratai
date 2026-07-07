-- Macro for incremental load with merge logic
{% macro incremental_merge(target_relation, source_relation, unique_key) %}
    {% if is_incremental() %}
        merge into {{ target_relation }} as target
        using {{ source_relation }} as source
        on target.{{ unique_key }} = source.{{ unique_key }}
        when matched then update set
            {% for column in adapter.get_columns_in_relation(target_relation) %}
                target.{{ column.name }} = source.{{ column.name }}
                {% if not loop.last %},{% endif %}
            {% endfor %}
        when not matched then insert
            ({{ adapter.get_columns_in_relation(target_relation) | map(attribute='name') | join(', ') }})
        values (
            {{ adapter.get_columns_in_relation(target_relation) | map(attribute='name') | join(', ') }}
        )
    {% else %}
        insert into {{ target_relation }}
        select * from {{ source_relation }}
    {% endif %}
{% endmacro %}

-- Macro to filter for incremental date
{% macro incremental_date_filter(date_column) %}
    {% if is_incremental() %}
        where {{ date_column }} > (select max({{ date_column }}) from {{ this }})
    {% endif %}
{% endmacro %}