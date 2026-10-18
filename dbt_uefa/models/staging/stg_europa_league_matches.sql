{{ config(
    materialized='table',
    schema='staging'
) }}


SELECT
    *
FROM
    {{ source('raw', 'europa_league_matches') }}
