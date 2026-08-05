{{ config(
    materialized='table',
    schema='default',
    alias='customers'
) }}

{{ load_csv_source(
    table_name='customers',
    csv_location='s3://warehouse/customers/customers.csv'
) }}

SELECT * FROM customers