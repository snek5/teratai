{% macro create_table_from_csv(table_name, csv_path, file_format='csv', options={}) %}

{% set default_options = {
    'header': 'true',
    'delimiter': ',',
    'nullValue': '',
    'inferSchema': 'true'
} %}

{% set all_options = default_options.update(options) %}

CREATE OR REPLACE TABLE {{ table_name }} AS
SELECT *
FROM {{ file_format }}.`{{ csv_path }}`
OPTIONS (
    {% for key, value in all_options.items() %}
    {{ key }} = '{{ value }}'{% if not loop.last %},{% endif %}
    {% endfor %}
)

{% endmacro %}