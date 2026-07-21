----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 04_export.sql — dashboard feeds (Power BI)
--
-- Author:  Diogo Grieco
-- Updated: v4.1-2026-07-20 (terceira auditoria — post-export staleness
--          check added at the end of this file; guards the exact failure
--          mode found by the 2026-07-20 audit (S18 item 7: parquets on
--          disk out of sync with the current tables/ordering), which
--          until now had no automated guard. Previously v4-2026-07-20 —
--          ranking redesign, single pbi_egs_ranking.parquet; see
--          03_analytics.sql v4 and sql_technical_fixes.md.)
--
-- Purpose: materialize the analytics tables as parquet files
--          in output/ (folder outside git; regenerable).
-- Run only after 01-03 have passed their checks.
--
-- CONFIGURATION — edit the path below to your local project clone
-- (same value as data_root in 01_staging.sql). The output/ folder
-- must already exist on disk — COPY does not create directories.
----------------------------------------------------------

COPY project2.analytics.egs_final
    TO 'C:/Users/diogo/projects/project2/output/pbi_egs_final.parquet' (FORMAT PARQUET);

COPY project2.analytics.egs_ranking
    TO 'C:/Users/diogo/projects/project2/output/pbi_egs_ranking.parquet' (FORMAT PARQUET);

COPY project2.analytics.annual_summary
    TO 'C:/Users/diogo/projects/project2/output/pbi_annual_summary.parquet' (FORMAT PARQUET);

----------------------------------------------------------
-- == EXPORT CHECK ==
-- export_ranking_stale (terceira auditoria, 2026-07-20): relê o parquet
-- recém-escrito e compara a ORDEM FÍSICA das suas 805 linhas com o
-- ranking recomputado de analytics.egs_final (média não-arredondada,
-- desempate por geocode — a mesma regra do ORDER BY de egs_ranking).
-- É a guarda para o modo de falha real do S18 item 7: parquet em disco
-- gerado antes de uma correção de ordenação, com conteúdo plausível e
-- ordem errada — nenhum check de contagem pega isso.
-- Nota: depende de preserve_insertion_order = true (padrão do DuckDB)
-- para que a leitura do parquet preserve a ordem do arquivo.
----------------------------------------------------------

WITH checks AS (
    SELECT 'export_ranking_stale' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '0' AS expected
    FROM (
        SELECT pq.geocode_ibge
        FROM (SELECT geocode_ibge, row_number() OVER () AS rk
              FROM 'C:/Users/diogo/projects/project2/output/pbi_egs_ranking.parquet') pq
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
