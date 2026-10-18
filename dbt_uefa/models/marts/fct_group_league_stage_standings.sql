{{ config(
    materialized='table',
    schema='marts'
) }}

WITH group_matches AS (
SELECT
    competition,
    season_start_year,
    host_country,
    host,
    host_goals,
    score,
    guest_goals,
    guest,
    guest_country
FROM
    {{ ref('int_euro_competition_matches') }}
WHERE
    round = 'Group stage' OR round = 'League phase'
),


-- matches unification, representing one match from both perspectives - home side & away side
normalized_matches AS (
    SELECT
        competition,
        season_start_year,
        host AS team,
        host_country AS country,
        guest AS opponent,
        guest_country AS opponent_country,
        host_goals AS gf,
        guest_goals AS ga,
        0 AS away_gf,
        CASE
            WHEN host_goals > guest_goals THEN 3
            WHEN host_goals = guest_goals THEN 1
            ELSE 0
        END AS pts,
        CASE WHEN host_goals > guest_goals THEN 1 ELSE 0 END AS win,
        0 AS away_win
    FROM group_matches

    UNION ALL

    SELECT
        competition,
        season_start_year,
        guest AS team,
        guest_country AS country,
        host AS opponent,
        host_country AS opponent_country,
        guest_goals AS gf,
        host_goals AS ga,
        guest_goals AS away_gf,
        CASE
            WHEN guest_goals > host_goals THEN 3
            WHEN guest_goals = host_goals THEN 1
            ELSE 0
        END AS pts,
        CASE WHEN guest_goals > host_goals THEN 1 ELSE 0 END AS win,
        CASE WHEN guest_goals > host_goals THEN 1 ELSE 0 END AS away_win
    FROM group_matches
),

-- creation of deterministic group id, this stage consists of 2 parts
-- 1/2 part: firstly we have to assign constant value that distinguish groups, to get this value we are going to extract first team in alphabetical order from each group
preparation_for_group_distinction AS (
    SELECT
        competition,
        season_start_year,
        team,
        country,
        CASE
            WHEN season_start_year IN (2024, 2025, 2026) THEN 'League Phase'
            ELSE MIN(LEAST(team, opponent)) OVER (PARTITION BY competition, season_start_year, team)
        END AS group_anchor
    FROM normalized_matches
    GROUP BY competition, season_start_year, team, country, opponent
),

-- 2/2 part: creation of ranking basing on the first team alphabetically at each group, after this operation we will have synthetic group ID number
group_distinction AS (
    SELECT DISTINCT
        competition,
        season_start_year,
        team,
        country,
        group_anchor,
        DENSE_RANK() OVER (
            PARTITION BY competition, season_start_year
            ORDER BY group_anchor ASC
        )::INTEGER AS group_idx
    FROM preparation_for_group_distinction
),

-- aggregating results of all teams in the group stage
overall_stats AS (
    SELECT
        m.competition,
        m.season_start_year,
        g.group_idx,
        g.group_anchor,
        m.team,
        m.country,
        COUNT(*)::INTEGER AS played,
        SUM(m.pts)::INTEGER AS total_pts,
        SUM(m.win)::INTEGER AS total_wins,
        SUM(m.away_win)::INTEGER AS total_away_wins,
        SUM(m.gf)::INTEGER AS total_gf,
        SUM(m.ga)::INTEGER AS total_ga,
        (SUM(m.gf) - SUM(m.ga))::INTEGER AS total_gd,
        SUM(m.away_gf)::INTEGER AS total_away_gf
    FROM normalized_matches m
    JOIN group_distinction g
        ON m.competition = g.competition
       AND m.season_start_year = g.season_start_year
       AND m.team = g.team
    GROUP BY m.competition, m.season_start_year, g.group_idx, g.group_anchor, m.team, m.country
),


-- H2H results between member of groups
h2h_pairs AS (
    SELECT
        competition,
        season_start_year,
        team,
        opponent,
        SUM(pts)::INTEGER AS h2h_pts,
        (SUM(gf) - SUM(ga))::INTEGER AS h2h_gd,
        SUM(gf)::INTEGER AS h2h_gf
    FROM normalized_matches
    GROUP BY competition, season_start_year, team, opponent
),

-- creation of "small table" between teams that have the same number of points for further ranking indication when teams have equal number of points
h2h_metrics AS (
    SELECT
        o1.competition,
        o1.season_start_year,
        o1.group_idx,
        o1.team,
        COALESCE(SUM(p.h2h_pts), 0)::INTEGER AS tied_h2h_pts,
        COALESCE(SUM(p.h2h_gd), 0)::INTEGER  AS tied_h2h_gd,
        COALESCE(SUM(p.h2h_gf), 0)::INTEGER  AS tied_h2h_gf
    FROM overall_stats o1
    JOIN overall_stats o2
        ON o1.competition = o2.competition
       AND o1.season_start_year = o2.season_start_year
       AND o1.group_idx = o2.group_idx
       AND o1.total_pts = o2.total_pts
       AND o1.team <> o2.team
    LEFT JOIN h2h_pairs p
        ON o1.competition = p.competition
       AND o1.season_start_year = p.season_start_year
       AND o1.team = p.team
       AND o2.team = p.opponent
    GROUP BY o1.competition, o1.season_start_year, o1.group_idx, o1.team
),

-- combining team performance at group stage table with small table with results between teams with the same number of points
combined_table AS (
SELECT
    o.*,
    COALESCE(h.tied_h2h_pts, 0) AS tied_h2h_pts,
    COALESCE(h.tied_h2h_gd, 0)  AS tied_h2h_gd,
    COALESCE(h.tied_h2h_gf, 0)  AS tied_h2h_gf
FROM overall_stats o
LEFT JOIN h2h_metrics h
    ON o.competition = h.competition
   AND o.season_start_year = h.season_start_year
   AND o.group_idx = h.group_idx
   AND o.team = h.team
),


-- steps to indicate final group/league position are divided into smaller, easier to understand parts.
-- part 1 of 3: addition of synthetic group name
assigned_group_labels AS (
    -- KROK 8: Wyznaczenie czytelnej nazwy grupy z cyfrą oraz flagi formatu
    SELECT
        c.*,
        (c.group_anchor = 'League Phase') AS is_league_phase,
        CASE
            WHEN c.group_anchor = 'League Phase' THEN 'League Phase'
            ELSE 'Group ' || c.group_idx::TEXT
        END AS group_name
    FROM combined_table c
),

-- part 2 of 3: summing up values of each team for H2H comparison in case of equal points, logic separated into 2 type, basing of edition of the competition
format_tie_breakers AS (
    SELECT
        agl.*,
        -- first criteria:
        	-- for group stage: H2H points
        	-- for league phase: total goal difference
        CASE WHEN NOT is_league_phase THEN tied_h2h_pts ELSE total_gd END AS crit_1,

        -- second criteria:
        	-- for group stage: H2H goal difference
        	-- for league phase: total goals for
        CASE WHEN NOT is_league_phase THEN tied_h2h_gd  ELSE total_gf END AS crit_2,

        -- third criteria:
        	-- for group stage: H2H goals for
        	-- for league phase: total away goals
        CASE WHEN NOT is_league_phase THEN tied_h2h_gf  ELSE total_away_gf END AS crit_3,

        -- fourth criteria:
        	-- for group stage: total goal difference
        	-- for league phase: total wins
        CASE WHEN NOT is_league_phase THEN total_gd     ELSE total_wins END AS crit_4,

        -- fifth criteria:
        	-- for group stage: total goals for
        	-- for league phase: total away wins
        CASE WHEN NOT is_league_phase THEN total_gf     ELSE total_away_wins END AS crit_5
    FROM assigned_group_labels agl
),


-- part 3 of 3: assigning final logic for position in group/league
final_standings AS (
SELECT
        competition,
        season_start_year,
        group_name,
        group_idx,
        ROW_NUMBER() OVER (
            PARTITION BY competition, season_start_year, group_idx
            ORDER BY
                total_pts DESC,
                crit_1    DESC NULLS LAST,
                crit_2    DESC NULLS LAST,
                crit_3    DESC NULLS LAST,
                crit_4    DESC NULLS LAST,
                crit_5    DESC NULLS LAST,
                total_away_gf DESC NULLS LAST,
                team      ASC
        ) AS position,
        team,
        country,
        played,
        total_pts,
        total_gd,
        total_gf,
        total_away_gf
    FROM format_tie_breakers
)

SELECT
    competition,
    season_start_year,
    group_name,
    position,
    team,
    country,
    played,
    total_pts,
    total_gd,
    total_gf,
    total_away_gf
FROM
	final_standings
ORDER BY
	competition,
	season_start_year,
	group_idx,
	position
