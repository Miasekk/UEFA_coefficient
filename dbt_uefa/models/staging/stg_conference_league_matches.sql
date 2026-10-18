{{ config(
    materialized='table',
    schema='staging'
) }}

SELECT
    *
FROM
    {{ source('raw', 'conference_league_matches') }}