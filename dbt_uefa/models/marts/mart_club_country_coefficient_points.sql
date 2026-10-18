{{ config(
    materialized='table',
    schema='marts'
) }}

with elimination_points as (
select
    season,
    season_start_year,
    country,
    team,
    SUM(eliminated_at_this_stage_points) as elimination_points
from
	 {{ ref('fct_club_last_phase_reached') }}
GROUP BY
    season,
    season_start_year,
    country,
    team
),

phase_points as (
select
    season,
    season_start_year,
    country,
    team,
    SUM(extra_points_for_reaching) as points_for_reached_rounds
from
	 {{ ref('fct_club_all_phases_reached') }}
group by
	season,
    season_start_year,
    country,
    team
),

competition_of_group_league_phase AS (
select
    season,
    season_start_year,
    country,
    competition,
    team
from
    {{ ref('fct_club_all_phases_reached') }}
WHERE
	round IN ('League phase','Group stage')
),

match_outcome_pts AS (
SELECT
	season,
	season_start_year,
	country,
	team,
	SUM(coef_pts_gained) AS pts_for_result
FROM
	{{ ref('fct_match_outcomes') }}
GROUP BY
	season,
    season_start_year,
    country,
    team
),

league_phase_status AS (
SELECT
	season,
	MAX(date) AS date_of_league_phase_end
FROM
	INTERMEDIATE.INT_EURO_COMPETITION_MATCHES IECM
WHERE
	round IN ('League phase', 'Group stage')
GROUP BY
	1
)

SELECT
	 participants.season_start_year,
	 participants.season,
	 countries.country_name,
	 participants.team,
	 league_group_phase_competition.competition AS league_group_phase_at,
	 league_group_standing.position AS position_league_phase,
	 CASE WHEN date_of_league_phase_end <=  NOW()::DATE THEN COALESCE(league_phase_pts.bonus_points,0) ELSE 0 END AS league_phase_bonus_pts,
	 COALESCE(league_phase_pts.bonus_points,0) AS projected_league_phase_bonus_pts,
     phase_points.points_for_reached_rounds,
	 outcome_points.pts_for_result,
	 COALESCE(phase_points.points_for_reached_rounds,0) + COALESCE(outcome_points.pts_for_result,0) + CASE WHEN date_of_league_phase_end <=  NOW()::DATE THEN COALESCE(league_phase_pts.bonus_points,0) ELSE 0 END  AS association_pts_gained,
	 COALESCE(phase_points.points_for_reached_rounds,0) + COALESCE(outcome_points.pts_for_result,0) + COALESCE(league_phase_pts.bonus_points,0) AS projected_association_pts_gained
FROM
    {{ ref('fct_participants_euro_competition') }} participants
LEFT JOIN
	elimination_points elimination_points ON
		participants.country = elimination_points.country AND
		participants.team = elimination_points.team AND
		participants.season_start_year = elimination_points.season_start_year
LEFT JOIN
	phase_points phase_points ON
		participants.country = phase_points.country AND
		participants.team = phase_points.team AND
		participants.season_start_year = phase_points.season_start_year
LEFT JOIN
	match_outcome_pts outcome_points ON
		participants.country = outcome_points.country AND
		participants.team = outcome_points.team AND
		participants.season_start_year = outcome_points.season_start_year
LEFT JOIN -- in which competition team played in group/league phase
	competition_of_group_league_phase league_group_phase_competition ON
		participants.country = league_group_phase_competition.country AND
		participants.team = league_group_phase_competition.team AND
		participants.season_start_year = league_group_phase_competition.season_start_year
LEFT JOIN -- position at group/league stage in given season of a team
    {{ ref('fct_group_league_stage_standings') }} league_group_standing ON
		participants.country = league_group_standing.country AND
		participants.team = league_group_standing.team AND
        participants.season_start_year = league_group_standing.season_start_year
LEFT JOIN -- position at league/group phase
    {{ ref('league_phase_bonus_points') }} league_phase_pts ON
	    league_group_standing.competition = league_phase_pts.competition AND
	    league_group_standing.position = league_phase_pts.ranking AND
	    (participants.season_start_year BETWEEN league_phase_pts.valid_from_season_starting_on AND league_phase_pts.valid_to_season_starting_on)
LEFT JOIN
	{{ ref('dim_countries') }} countries ON
		LOWER(participants.country) = LOWER(
            CASE
                WHEN LENGTH(TRIM(participants.country)) = 2  THEN countries.country_code_alpha_two
                WHEN LENGTH(TRIM(participants.country)) = 3  THEN countries.country_code_fifa
                ELSE countries.country_name  -- opcjonalnie: dopasowanie po pełnej nazwie, jeśli kod ma > 3 znaki
            END
    )
LEFT JOIN
    league_phase_status ON
        league_phase_status.season = participants.season
