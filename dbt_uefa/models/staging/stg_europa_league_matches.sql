{{ config(materialized='table') }}

SELECT
    *
FROM
    {{ source('staging', 'europa_league_matches') }}