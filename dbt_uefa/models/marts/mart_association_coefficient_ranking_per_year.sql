{{ config(
    materialized='table',
    schema='marts'
) }}

WITH points_five_seasons AS (
    SELECT
    season,
    season_start_year,
    country_name,
    association_points,
    SUM(association_points) OVER (PARTITION BY country_name ORDER BY season_start_year ASC ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING) as five_years_coef_summary
FROM
    marts.mart_association_coefficient_points_yearly
GROUP BY
    season,
    season_start_year,
    country_name,
    association_points
)

SELECT
	season,
	season_start_year,
	country_name,
	five_years_coef_summary,
	RANK() OVER (PARTITION BY season ORDER BY five_years_coef_summary DESC) AS yearly_ranking
FROM
    points_five_seasons
WHERE
	season_start_year >= 2026

