{{ config(
    materialized='table',
    schema='marts'
) }}

WITH current_season AS (
SELECT
	MAX(season_start_year) AS current_season
FROM
	{{ ref('mart_association_coefficient_points_yearly') }}
),

future_seasons AS (
SELECT
    future_year AS season_start_year,
    CONCAT(future_year, '/', future_year + 1) AS season
FROM
	current_season c
CROSS JOIN LATERAL
	generate_series(c.current_season + 1, c.current_season + 4) AS future_year
),

distinct_countries AS (
SELECT
	DISTINCT country_name
FROM
	{{ ref('mart_association_coefficient_points_yearly') }}
),

future_season_per_country AS (
SELECT
	fs.season_start_year,
	fs.season,
	cn.country_name
FROM
	future_seasons fs
CROSS JOIN
	distinct_countries cn
),

points_collected_yearly_per_country AS (
SELECT
DISTINCT
	season,
	season_start_year,
	country_name,
	association_points
FROM
	{{ ref('mart_association_coefficient_points_yearly') }}

UNION ALL

SELECT
	season,
	season_start_year,
	country_name,
	0 AS association_points
FROM
	future_season_per_country

),

five_years_access_list AS (
SELECT
	season,
	season_start_year,
	country_name,
	association_points,
	SUM(association_points) OVER (PARTITION BY country_name ORDER BY season_start_year ASC ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING) as five_years_coef_summary
FROM
	points_collected_yearly_per_country
GROUP BY
	season,
	season_start_year,
	country_name,
	association_points
),

prev_years_pts_pivot AS (
SELECT
	season,
	season_start_year,
	country_name,
	five_years_coef_summary,
	COALESCE(LAG(association_points,1) OVER(PARTITION BY country_name ORDER BY season_start_year ASC),0) AS points_year_ago,
	COALESCE(LAG(association_points,2) OVER(PARTITION BY country_name ORDER BY season_start_year ASC),0) AS points_two_year_ago,
	COALESCE(LAG(association_points,3) OVER(PARTITION BY country_name ORDER BY season_start_year ASC),0) AS points_three_year_ago,
	COALESCE(LAG(association_points,4) OVER(PARTITION BY country_name ORDER BY season_start_year ASC),0) AS points_four_year_ago,
	COALESCE(LAG(association_points,5) OVER(PARTITION BY country_name ORDER BY season_start_year ASC),0) AS points_five_year_ago
FROM
	five_years_access_list
)

SELECT
	CAST(season_start_year+1 AS TEXT) || '/'  || RIGHT(CAST(season_start_year+2 AS TEXT),2) AS season,
	season_start_year+1 AS season_starting_on,
	country_name,
	five_years_coef_summary,
	points_year_ago,
	points_two_year_ago,
	points_three_year_ago,
	points_four_year_ago,
	points_five_year_ago,
	RANK() OVER(PARTITION BY season ORDER BY five_years_coef_summary DESC, points_year_ago DESC, points_two_year_ago DESC, points_three_year_ago DESC, points_four_year_ago DESC, points_five_year_ago DESC) AS ranking
FROM
	prev_years_pts_pivot
WHERE
	season_start_year >= 2026