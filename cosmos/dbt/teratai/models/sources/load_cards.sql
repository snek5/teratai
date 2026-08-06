{{ config(
    materialized='table',
    schema='default',
    alias='cards'
) }}

{{ load_csv_source(
    table_name='cards',
    csv_location='s3://warehouse/cards/cards.csv'
) }}

SELECT * FROM cards