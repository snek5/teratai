{{ config(
    materialized='table',
    schema='default',
    alias='loans'
) }}

{{ load_csv_source(
    table_name='loans',
    csv_location='s3://warehouse/loans/loans.csv'
) }}

SELECT * FROM loans