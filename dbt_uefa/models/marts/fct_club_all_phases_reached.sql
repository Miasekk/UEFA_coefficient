{{ config(
    materialized='table',
    schema='marts'
) }}

WITH club_matches AS (
    SELECT
        competition,
        season_start_year,
        season,
        round,
        host_country AS country,
        host AS team
    FROM
        {{ ref('int_euro_competition_matches') }}

    UNION ALL

    SELECT
        competition,
        season_start_year,
        season,
        round,
        guest_country AS country,
        guest AS team
    FROM
        {{ ref('int_euro_competition_matches') }}
)


SELECT
    DISTINCT
        season,
        season_start_year,
        competition,
        country,
        team,
        round
FROM
    club_matches
