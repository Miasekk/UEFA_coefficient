{{ config(materialized='table') }}

SELECT
    *
FROM
    {{ source('staging', 'conference_league_matches') }}