-- Macro to generate surrogate key with null handling
{% macro generate_surrogate_key(columns) %}
    coalesce(
        {{ dbt_utils.generate_surrogate_key(columns) }},
        {{ dbt_utils.generate_surrogate_key(['null']) }}
    )
{% endmacro %}

-- Macro to generate composite business key
{% macro business_key(columns) %}
    {{ columns | join(' || '~' || ') }}
{% endmacro %}