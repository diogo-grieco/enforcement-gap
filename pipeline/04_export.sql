----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 04_export.sql: dashboard/analysis feeds
--
-- Author: Diogo Grieco
--
-- Purpose: materialize the analytics tables as parquet files
--          in output/parquets/. Run only after 01-03 pass.
----------------------------------------------------------

COPY project2.analytics.egs_final
    TO (getvariable('data_root') || '/output/parquets/egs_final.parquet') (FORMAT PARQUET);

COPY project2.analytics.egs_ranking
    TO (getvariable('data_root') || '/output/parquets/egs_ranking.parquet') (FORMAT PARQUET);

COPY project2.analytics.annual_summary
    TO (getvariable('data_root') || '/output/parquets/annual_summary.parquet') (FORMAT PARQUET);

----------------------------------------------------------
-- == EXPORT CHECK ==
-- export_ranking_stale: catches a parquet written before an ordering
-- fix (right rows, wrong order), which no row-count check would see.
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
