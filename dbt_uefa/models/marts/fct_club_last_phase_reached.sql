{{ config(
    materialized='table',
    schema='marts'
) }}

WITH club_matches AS (
    SELECT
        competition,
        season_start_year,
        season,
        date,
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
        date,
        round,
        guest_country AS country,
        guest AS team
    FROM
        {{ ref('int_euro_competition_matches') }}
),

ranked_matches AS (
    SELECT
        season,
        season_start_year,
        competition,
        country,
        team,
        round,
        date,
        ROW_NUMBER() OVER (
            PARTITION BY season, season_start_year, competition, team
            ORDER BY date DESC
        ) AS rn
    FROM
        club_matches
)

SELECT
    ranked_matches.season,
    ranked_matches.season_start_year,
    ranked_matches.competition,
    ranked_matches.country,
    ranked_matches.team,
    ranked_matches.round AS last_phase_reached,
    points.eliminated_at_this_stage_points
FROM
    ranked_matches
left join
	{{ ref('euro_competition_points') }} points on
		ranked_matches.competition = points.competition and
		(ranked_matches.season_start_year between points.valid_from_season_starting_on and points.valid_to_season_starting_on) and
		ranked_matches.round = points.round
WHERE
    rn = 1