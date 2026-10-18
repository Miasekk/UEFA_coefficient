{{ config(
    materialized='table',
    schema='marts'
) }}

WITH base_countries AS (
    SELECT
        country_name,
        country_code_alpha_two,
        country_code_alpha_three,
        country_code_fifa,
        country_url_png,
        country_url_svg,
        country_region,
        country_subregion,
        country_continents,
        country_area_km,
        country_cars_side,
        country_population,
        country_african_union_member,
        country_arab_league_member,
        country_asean_member,
        country_brics_member,
        country_commonwealth_member,
        country_eu_member,
        country_eurozone_member,
        country_gtwenty_member,
        country_gseven_member,
        country_nato_member,
        country_oecd_member,
        country_opec_member,
        country_schengen_member,
        country_un_member
    FROM
        {{ ref('stg_countries') }}
),

uk_nations AS (
    SELECT
        'England' AS country_name,
        'GB-ENG' AS country_code_alpha_two,
        'GBR' AS country_code_alpha_three,
        'ENG' AS country_code_fifa,
        'https://flagcdn.com/w320/gb-eng.png' AS country_url_png,
        'https://flagcdn.com/gb-eng.svg' AS country_url_svg,
        'Europe' AS country_region,
        'Northern Europe' AS country_subregion,
        'Europe' AS country_continents,
        130279.0::numeric AS country_area_km,
        'left' AS country_cars_side,
        56500000::bigint AS country_population,
        false AS country_african_union_member,
        false AS country_arab_league_member,
        false AS country_asean_member,
        false AS country_brics_member,
        true AS country_commonwealth_member,
        false AS country_eu_member,
        false AS country_eurozone_member,
        false AS country_gtwenty_member,
        false AS country_gseven_member,
        false AS country_nato_member,
        true AS country_oecd_member,
        false AS country_opec_member,
        false AS country_schengen_member,
        false AS country_un_member

    UNION ALL

    SELECT
        'Scotland',
        'GB-SCT',
        'GBR',
        'SCT',
        'https://flagcdn.com/w320/gb-sct.png',
        'https://flagcdn.com/gb-sct.svg',
        'Europe',
        'Northern Europe',
        'Europe',
        77933.0::numeric,
        'left',
        5450000::bigint,
        false, false, false, false, true, false, false, false, false, false, true, false, false, false

    UNION ALL

    SELECT
        'Wales',
        'GB-WLS',
        'GBR',
        'WLS',
        'https://flagcdn.com/w320/gb-wls.png',
        'https://flagcdn.com/gb-wls.svg',
        'Europe',
        'Northern Europe',
        'Europe',
        20779.0::numeric,
        'left',
        3100000::bigint,
        false, false, false, false, true, false, false, false, false, false, true, false, false, false

    UNION ALL

    SELECT
        'Northern Ireland',
        'GB-NIR',
        'GBR',
        'NIR',
        'https://flagcdn.com/w320/gb-nir.png',
        'https://flagcdn.com/gb-nir.svg',
        'Europe',
        'Northern Europe',
        'Europe',
        14130.0::numeric,
        'left',
        1900000::bigint,
        false, false, false, false, true, false, false, false, false, false, true, false, false, false
)

SELECT * FROM base_countries
UNION ALL
SELECT * FROM uk_nations