{{ config(
    materialized='table',
    schema='default',
    alias='branches'
) }}

{{ load_csv_source(
    table_name='branches',
    csv_location='s3://warehouse/branches/branches.csv'
) }}

SELECT * FROM branches