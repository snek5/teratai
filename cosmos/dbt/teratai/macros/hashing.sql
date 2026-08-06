-- Macro for sensitive data masking
{% macro mask_pii(column_name) %}
    case 
        when {{ column_name }} is null then null
        else concat(
            left({{ column_name }}, 3),
            '********',
            right({{ column_name }}, 4)
        )
    end
{% endmacro %}

-- Macro to hash sensitive columns
{% macro hash_column(column_name, algorithm='sha256') %}
    {{ algorithm }}({{ column_name }})
{% endmacro %}