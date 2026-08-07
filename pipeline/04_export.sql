----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 04_export.sql: dashboard/analysis feeds
--
-- Author: Diogo Grieco
--
-- Purpose: materialize the analytics tables as parquet files
--          in output/parquets/ (final exports are versioned; viz_*
--          intermediate caches are not).
-- Run only after 01-03 have passed their checks.
--
-- CONFIGURATION: no path to edit here. Every destination below is built
-- from getvariable('data_root'), the single configuration point set at the
-- top of 01_staging.sql; run this file on the same connection (the variable
-- is session-scoped). The output/parquets/ folder must already exist on
-- disk; COPY does not create directories.
-- Note on syntax: COPY ... TO does NOT accept a bare expression, but it does
-- accept a PARENTHESIZED one: the enclosing ( ... ) around the concatenation
-- below is required, not decorative.
----------------------------------------------------------

COPY project2.analytics.egs_final
    TO (getvariable('data_root') || '/output/parquets/egs_final.parquet') (FORMAT PARQUET);

COPY project2.analytics.egs_ranking
    TO (getvariable('data_root') || '/output/parquets/egs_ranking.parquet') (FORMAT PARQUET);

COPY project2.analytics.annual_summary
    TO (getvariable('data_root') || '/output/parquets/annual_summary.parquet') (FORMAT PARQUET);

----------------------------------------------------------
-- == EXPORT CHECK ==
-- export_ranking_stale: re-reads the just-written parquet and compares
-- the PHYSICAL ORDER of its 772 rows against the ranking recomputed from
-- analytics.egs_final (unrounded mean, geocode tiebreak, the same rule
-- as egs_ranking's ORDER BY). Guards against a parquet on disk generated
-- before an ordering fix, with plausible content but wrong order: a
-- failure mode no row-count check would catch.
-- Note: depends on preserve_insertion_order = true (DuckDB default) so
-- that reading the parquet preserves the file's row order.
----------------------------------------------------------

WITH checks AS (
    SELECT '01_export_ranking_stale' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '0' AS expected
    FROM (
        SELECT pq.geocode_ibge
        FROM (SELECT geocode_ibge, row_number() OVER () AS rk
              FROM read_parquet(getvariable('data_root') || '/output/parquets/egs_ranking.parquet')) pq
        JOIN (SELECT geocode_ibge, row_number() OVER (ORDER BY AVG(egs) DESC, geocode_ibge) AS rk
              FROM project2.analytics.egs_final GROUP BY geocode_ibge) t
        USING (geocode_ibge)
        WHERE pq.rk != t.rk
    )
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name;   -- 'failed' > 'OK' na colação binária: falhas no topo
