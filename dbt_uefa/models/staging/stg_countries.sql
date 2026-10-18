{{ config(
    materialized='table',
    schema='staging'
) }}

SELECT
    *
FROM
    {{ source('raw', 'countries') }}