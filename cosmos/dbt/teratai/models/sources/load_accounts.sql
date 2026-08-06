{{ config(
    materialized='table',
    schema='default',
    alias='accounts'
) }}

{{ load_csv_source(
    table_name='accounts',
    csv_location='s3://warehouse/accounts/accounts.csv'
) }}

SELECT * FROM accounts