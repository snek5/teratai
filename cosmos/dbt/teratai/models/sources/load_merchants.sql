{{ config(
    materialized='table',
    schema='default',
    alias='merchants'
) }}

{{ load_csv_source(
    table_name='merchants',
    csv_location='s3://warehouse/merchants/merchants.csv'
) }}

SELECT * FROM merchants