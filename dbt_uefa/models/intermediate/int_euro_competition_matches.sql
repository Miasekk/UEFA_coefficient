{{ config(
    materialized='table',
    schema='intermediate'
) }}

SELECT
    competition,
    season,
    season_start_year,
    round,
    matchweek,
    day,
    date,
    time,
    host_country,
    host,
    host_goals,
    score,
    guest_country,
    guest,
    guest_goals,
    attendance,
    venue,
    referee,
    notes,
    competition_phase,
    extra_time,
    penalty_kicks,
    penalty_kicks_result,
    host_penalties_scored,
    guest_penalties_scored
FROM
    {{ ref('stg_champions_league_matches') }}

UNION ALL

SELECT
    competition,
    season,
    season_start_year,
    round,
    matchweek,
    day,
    date,
    time,
    host_country,
    host,
    host_goals,
    score,
    guest_country,
    guest,
    guest_goals,
    attendance,
    venue,
    referee,
    notes,
    competition_phase,
    extra_time,
    penalty_kicks,
    penalty_kicks_result,
    host_penalties_scored,
    guest_penalties_scored
FROM
    {{ ref('stg_conference_league_matches') }}

UNION ALL

SELECT
    competition,
    season,
    season_start_year,
    round,
    matchweek,
    day,
    date,
    time,
    host_country,
    host,
    host_goals,
    score,
    guest_country,
    guest,
    guest_goals,
    attendance,
    venue,
    referee,
    notes,
    competition_phase,
    extra_time,
    penalty_kicks,
    penalty_kicks_result,
    host_penalties_scored,
    guest_penalties_scored
FROM
    {{ ref('stg_europa_league_matches') }}
