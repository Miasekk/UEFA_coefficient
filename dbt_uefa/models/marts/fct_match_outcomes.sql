{{ config(
    materialized='table',
    schema='marts'
) }}

WITH match_outcome AS (
SELECT
	competition,
	season,
	season_start_year,
	round,
	host_country AS country,
	host AS team,
	CASE
		WHEN host_goals = guest_goals THEN 'draw'
		WHEN host_goals > guest_goals THEN 'win'
		WHEN host_goals < guest_goals THEN 'lose'
	END AS match_result
FROM
	{{ ref('int_euro_competition_matches')}}

UNION ALL

SELECT
	competition,
	season,
	season_start_year,
	round,
	guest_country,
	guest,
	CASE
		WHEN host_goals = guest_goals THEN 'draw'
		WHEN host_goals > guest_goals THEN 'lose'
		WHEN host_goals < guest_goals THEN 'win'
	END AS match_result
FROM
	{{ ref('int_euro_competition_matches')}}
	)


SELECT
	m_out.competition,
	m_out.season,
	m_out.season_start_year,
	m_out.round,
	m_out.country,
	m_out.team,
	m_out.match_result,
	CASE
		WHEN m_out.match_result = 'draw' THEN points.draw_pts
		WHEN m_out.match_result = 'win' THEN points.win_pts
		WHEN m_out.match_result = 'lose' THEN points.lose_pts
	END AS coef_pts_gained
FROM
	match_outcome m_out
LEFT JOIN
	{{ ref('euro_competition_points')}} points ON
		m_out.competition = points.competition AND
		(m_out.season_start_year BETWEEN points.valid_from_season_starting_on AND points.valid_to_season_starting_on) AND
		m_out.round = points.round
