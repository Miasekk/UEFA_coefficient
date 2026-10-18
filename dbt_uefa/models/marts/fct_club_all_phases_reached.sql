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
),

phases_reached AS (
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
)

SELECT
    phases_reached.season,
    phases_reached.season_start_year,
    phases_reached.competition,
    phases_reached.country,
    phases_reached.team,
    phases_reached.round,
    points.extra_points_for_reaching
FROM
    phases_reached
left join
	{{ ref('euro_competition_points') }} points on
		phases_reached.competition = points.competition and
		(phases_reached.season_start_year between points.valid_from_season_starting_on and points.valid_to_season_starting_on) and
		phases_reached.round = points.round
