{{ config(
    materialized='table',
    schema='marts'
) }}

WITH regular_countries AS (
    SELECT
        season_start_year,
        season,
        country_name,
        SUM(association_pts_gained) AS total_pts_by_country,
        COUNT(team) AS teams_in_euro_competition,
        TRUNC((SUM(association_pts_gained)::numeric / NULLIF(COUNT(team), 0)), 3) AS association_points
    FROM
        {{ ref('mart_club_country_coefficient_points') }}
    -- Wykluczamy Rosję z normalnego sumowania od momentu bana:
    WHERE NOT (LOWER(country_name) IN ('russia', 'russian federation') AND season_start_year >= 2022)
    GROUP BY
        season_start_year,
        season,
        country_name
),

russia_ban_seasons AS (
    -- Wyciągamy wszystkie unikalne sezony od 2022 roku, które występują w bazie:
    SELECT DISTINCT
        season_start_year,
        season,
        'Russia' AS country_name,
        0.0::numeric AS total_pts_by_country,
        0 AS teams_in_euro_competition,
        4.333::numeric AS association_points  -- Stały współczynnik przyznany przez UEFA
    FROM
        {{ ref('mart_club_country_coefficient_points') }}
    WHERE
        season_start_year >= 2022
)

SELECT
    season_start_year,
    season,
    country_name,
    total_pts_by_country,
    teams_in_euro_competition,
    association_points
FROM
    regular_countries

UNION ALL

SELECT
    season_start_year,
    season,
    country_name,
    total_pts_by_country,
    teams_in_euro_competition,
    association_points
FROM
russia_ban_seasons