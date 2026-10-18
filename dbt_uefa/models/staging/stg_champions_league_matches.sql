{{ config(
    materialized='table',
    schema='staging'
) }}

SELECT
    *
FROM
    {{ source('raw', 'champions_league_matches') }}