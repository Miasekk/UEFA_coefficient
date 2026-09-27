{{ config(materialized='table') }}

SELECT
    *
FROM
    {{ source('staging', 'champions_league_matches') }}