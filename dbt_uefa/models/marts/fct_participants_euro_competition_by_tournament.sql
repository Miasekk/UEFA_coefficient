{{ config(
    materialized='table',
    schema='marts'
) }}

with all_matches as (
SELECT
    competition,
    season_start_year,
    season,
    host_country AS country,
    host AS team
FROM
    {{ ref('int_euro_competition_matches') }}

UNION ALL

SELECT
    competition,
    season_start_year,
    season,
    guest_country AS country,
    guest AS team
FROM
    {{ ref('int_euro_competition_matches') }}
   )

select
	DISTINCT
	    competition,
		season_start_year,
	    season,
	    country,
	    team
from
	all_matches