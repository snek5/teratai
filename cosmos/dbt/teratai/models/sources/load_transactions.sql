{{ config(
    materialized='table',
    schema='default',
    alias='transactions'
) }}

{{ load_csv_source(
    table_name='transactions',
    csv_location='s3://warehouse/transactions/transactions.csv',
) }}

SELECT * FROM transactions