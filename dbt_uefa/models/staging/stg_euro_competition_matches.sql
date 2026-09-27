{{ config(materialized='table') }}

SELECT
    *
FROM
    {{ source('staging', 'all_european_competition_matches') }}