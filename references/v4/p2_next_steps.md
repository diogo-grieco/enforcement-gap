# EGMS — Next Steps
**Status:** Pipeline v5 (staging deflator + municipios_ref + analytics v2). Documento original gerado 2026-05-03, sobre pipeline v2. Última atualização (2026-07-12): UF validada em produção — pipeline completo rodado no DBeaver contra dados reais pelo autor, todos os checks confirmados.

---

## Changelog 2026-07-12 — UF fechada

- **`municipios_ref`:** ✅ CONCLUÍDO. Fonte final: API de localidades do IBGE (JSON, baixada manualmente — o site do DTB/xls estava inacessível). Estrutura verificada com Python antes do SQL: 5.571 municípios, 0 duplicatas, cobertura de UF 100%. Ver Fix 12 em `p2_technical_fixes.txt`.
- **UF em marts/analytics:** ✅ CONCLUÍDO e **validado em produção** — não só revisão de código. Diogo rodou `01_staging.sql` → `04_export.sql` no DBeaver contra os dados reais e confirmou: `n_municipios_ref`=5.571, `geocodes_duplicados`=0, `geocode_ref_invalido`=0, `uf_ausente`=0, `sem_referencia`=0, `sem_uf`=0.
- **Bloco 6 (Power BI):** deixa de estar bloqueado por UF — item que travava três blocos diferentes está resolvido.
- **NOVO — portabilidade (`data_root`):** ao rodar pela primeira vez fora do ambiente de desenvolvimento, os paths relativos falharam no DBeaver (resolvidos contra o cwd do processo, não a raiz do projeto). Resolvido com `SET VARIABLE data_root` + `getvariable()` em `01_staging.sql` — um único ponto de configuração, portável entre DBeaver/CLI/R. Ver Fix 14 em `p2_technical_fixes.txt`. Motivado por preparação para publicação em GitHub/Zenodo.

---

## Changelog 2026-07-10

- **Priority flag (streak=1 → priority_score=0):** ✅ RESOLVIDO. Não pela correção sugerida (`LOG(streak+1)`) — o filtro `streak_length >= 3` roda antes da agregação que calcula `priority_score`, então `MAX(streak_length)=1` nunca chega ao `LOG()`. Ver `p2_technical_fixes.txt` Fix 10.
- **Bloco 2 (staging) — `ipca_deflator`:** ✅ CONCLUÍDO. Implementado em `01_staging.sql` com valores reais do Sidra (não os aproximados que circulavam antes). Ver Fix 2 em `p2_technical_fixes.txt`.
- **Bloco 2 (staging) — `municipios_ref`:** ✅ CONCLUÍDO em 2026-07-12 (ver changelog acima). Estava aberto no momento desta nota.
- **Bloco 4 (analytics) — threshold p75:** ✅ RESOLVIDO. Deixou de ser hardcoded; `PERCENTILE_CONT(0.75)` agora roda em CTE a cada execução.
- **Bloco 4 (analytics) — UF fix:** ✅ RESOLVIDO em 2026-07-12 (ver changelog acima) — era regressão no momento desta nota, fechada com `municipios_ref` via API IBGE e validação em produção.
- **Bloco 4 (analytics) — Barra do Bugres:** ⚠ AINDA ABERTO. Nenhuma menção nos arquivos atualizados.
- **NOVO — classificação `tipo_egs`:** threshold de materialidade (`area_km2 >= 1`) agora aplicado de forma consistente também ao limite gap_absoluto/sem_pressao (v3 usava `>0`, inconsistente com o restante do documento). Ver Fix 11.
- **NOVO — `egs` para `sem_pressao`:** mudou de `0` para `NULL`, sem registro em changelog até esta atualização. Ver Fix 13.

---

## Block 1 — R exploration script (→ closed commit)

**Objetivo original:** understand, validate, and close the script as an auditable document before committing to GitHub.

### Status dos review items (v4)

- **IBAMA filters:** ✅ Confirmado — 3 casos idênticos entre `exploring_script.R` v4 e `02_marts.sql`, mesmos 6 códigos em `CODIGOS_DESMATAMENTO`.
- **Date handling:** ✅ `DAT_HORA_AUTO_INFRACAO`, 0 NAs confirmado (`NA_IBAMA_DATES <- 0`).
- **Lag analysis (4 sub-análises):** ✅ Presente no script v4 — `pct_so_t`, `pct_so_t1`, `pct_ambos`, `pct_nenhum` somam 100% (4.7 + 1.0 + 59.2 + 35.1).
- **Sensitivity analysis:** ✅ Presente e com `stopifnot` — gap_absoluto=3.063, recuperados=724, 23.6%.
- **Volume bias analysis:** ✅ Documentado em `project2_session_reference_v3.md` §3.2 (não repetido no script R, mas registrado).
- **PRODES temporal coverage (< 18 anos?):** ✅ Verificado — painel balanceado 805 × 18 = 14.490, confirmado por `stopifnot` no R e checks em `02_marts.sql`.
- **PRODES annual distribution — quebras estruturais (INPE methodology changes):** ⚠ AINDA ABERTO. O script R lista a distribuição por ano (`count(ano)`) mas não há análise ou comentário sobre quebras estruturais / mudanças de metodologia do INPE. Item não avançou desde maio.

### Best practices — status
- Constantes nomeadas no topo do script (`NROW_IBAMA_RAW`, `N_GAP_ABSOLUTO`, etc.): ✅ feito.
- `stopifnot` após cada etapa crítica: ✅ feito (leitura, filtro, data, valor, PRODES, sensibilidade, IPCA).
- Seções nomeadas com cabeçalho: ✅ feito.

**Bloco 1: essencialmente concluído.** Pendência real: quebras estruturais PRODES.

---

## Block 2 — Staging layer (01_staging.sql)

### Status dos items

- **`ipca_deflator`:** ✅ CONCLUÍDO (2026-07-10). Implementado com UNPIVOT + filtro regex contra vazamento do rodapé Sidra, `parallel = false` documentado como necessário para `null_padding` funcionar com quebras de linha entre aspas no rodapé (DuckDB ≥ 1.5).
- **`municipios_ref`:** ✅ CONCLUÍDO (2026-07-12). Fonte: API de localidades IBGE (JSON), não o DTB/csv originalmente planejado. Estrutura verificada com Python antes do SQL. Validado em produção: `n_municipios_ref`=5.571, `geocodes_duplicados`=0, `uf_ausente`=0.
- **Geocode digit check (IBAMA):** ✅ CONCLUÍDO. Check presente em `01_staging.sql`: `LENGTH(CAST(COD_MUNICIPIO AS VARCHAR)) != 7`.
- **NOVO — `data_root` configurável:** ✅ CONCLUÍDO (2026-07-12, não estava no escopo original deste bloco). `SET VARIABLE data_root` no topo de `01_staging.sql`, substitui os paths relativos (que falhavam no DBeaver) e os paths hardcoded pessoais que vieram em seguida. Ver Fix 14 em `p2_technical_fixes.txt`.

### Checks — status
Todos os checks propostos no documento original estão implementados e **confirmados contra dados reais** em `01_staging.sql`, incluindo os que dependiam de `municipios_ref` (cobertura de anos IPCA, deflator válido, geocode inválido, contagem/duplicata/UF ausente em municipios_ref, PRODES sem referência).

**Bloco 2: concluído.**

---

## Block 3 — Marts layer (02_marts.sql)

### Status dos items

- **Fix 9 — filtro 3 casos:** ✅ APLICADO e confirmado idêntico ao R.
- **UF sourcing via `municipios_ref`:** ✅ RESOLVIDO (2026-07-12), mas não em `02_marts.sql` como o plano original previa — o join com `municipios_ref` ficou na camada analytics (`03_analytics.sql`), não em `ibama_clean`. `02_marts.sql` continua sem UF, por design: a fonte de verdade de UF é `municipios_ref`, não o IBAMA. Ver Fix 12 em `p2_technical_fixes.txt`.

### Checks — status
Todos os checks propostos (`null_ano`, range de anos, `val_multa` negativa) estão implementados em `02_marts.sql`, mais checks adicionais não pedidos originalmente (total de multas, painel PRODES balanceado, NAs em `prodes_clean`).

**Bloco 3: concluído.**

---

## Block 4 — Analytics layer (03_analytics.sql → review + checks + commit)

### Status dos items

**Streak mechanism review:** ✅ Revisado. O padrão `ROW_NUMBER() + (ano - rn)` está documentado com comentários explicando o mecanismo. Casos-limite (município com 1 ano de dado, gap interrompendo streak) não têm teste unitário dedicado, mas o filtro `streak_length >= 3` cobre o caso de streak=1 isolado.

**Priority score review:** ✅ Resolvido — ver Fix 10 em `p2_technical_fixes.txt`. Comportamento documentado explicitamente como decisão de design no comentário (d) do SQL: "streak 1-2 não é zerado pelo LOG, é excluído por regra de persistência... Design, não bug."

**Threshold p75:** ✅ Resolvido — não é mais hardcoded, calculado via `PERCENTILE_CONT(0.75)` em CTE a cada execução (ver Fix 3 em `p2_technical_fixes.txt`).

**Threshold de 3 anos:** ✅ Documentado como decisão de design no cabeçalho de `03_analytics.sql` (ciclo eleitoral brasileiro).

**UF fix:** ✅ Resolvido e validado em produção (ver Bloco 3 acima e Fix 12). `uf` e `nome_municipio` propagados até `egs_final`, `ranking_gap_absoluto` e `ranking_completo`. Check novo `sem_uf` confirmado em 0 pelo autor.

**Barra do Bugres:** ⚠ AINDA ABERTO. Pesquisa externa sobre % de desmatamento legal via AUTEX/DOF não foi feita. Nenhuma menção no pipeline atual.

### Checks — status
Implementados em `03_analytics.sql`: total de linhas (14.490), distribuição por `tipo_egs`, p75 de referência, cobertura de UF (`sem_uf`, confirmado 0). **Não implementado:** check explícito de "EGS deve ser >= 0" (proposto no documento original) — hoje `egs` pode ser `NULL` para `sem_pressao` (Fix 13), então esse check precisaria ser reescrito para `WHERE egs < 0` sem quebrar em `NULL`. Também não implementado: check de duplicidade `geocode_ibge, ano`.

**Bloco 4: streak/priority_score/p75/UF resolvidos e validados. Item aberto: Barra do Bugres (isolado, não bloqueia mais nada).**

---

## Block 5 — Documentation

**Status:** não iniciado. `README`, apêndice metodológico e atualização das narrativas (`p2_narrative_draft.md`, `p2_results_narrative_draft.md`, `p2_onepager.md`) seguem pendentes. Esses três documentos citam números do pipeline v3 (completo=7.893/54.5%, gap_absoluto=3.784/26.1%, sem_pressao=2.813/19.4%, p75=0.727) que estão desatualizados em relação ao pipeline v5, **confirmado em produção em 2026-07-12**: completo=3.285 (22.7%), gap_absoluto=3.063 (21.1%), sem_pressao=8.142 (56.2%), p75=0.7027. A queda grande em `completo` e o salto em `sem_pressao` refletem a mudança de threshold de materialidade (Fix 11: `area_km2 > 0` → `>= 1`), não uma mudança de metodologia de enforcement — mas **precisa ser explicado assim na narrativa**, para não parecer um resultado súbito e não-intencional. Ver §6.2 de `project2_session_reference_v5.md` para o detalhamento completo.

---

## Block 6 — Power BI

**Status:** não iniciado, mas **desbloqueado** — UF (Fix 12) está resolvida e validada, `04_export.sql` já materializa `uf`/`nome_municipio` nos 4 parquets. Nenhum item deste bloco tem bloqueio pendente no momento.

---

## Execution order (revisado 2026-07-12)

```
Block 1  →  Block 2  →  Block 3  →  Block 4  →  Block 5  →  Block 6
R review    staging     marts       analytics    docs         Power BI
(quebras    ✅          ✅          ✅          (regenerar   (desbloqueado
estruturais  concluído   concluído   concluído,   narrativas   — pronto para
PRODES —                             Barra do     com          iniciar)
único item                           Bugres       números
aberto)                              aberto)      atuais)
```

**Caminho crítico anterior (resolvido):** `municipios_ref` → UF → choropleth. Fechado em 2026-07-12, validado em produção pelo autor.

**Itens em aberto, agora isolados (não bloqueiam mais nada entre si):**
1. Quebras estruturais do PRODES (Bloco 1)
2. Barra do Bugres (Bloco 4)
3. Documentação/narrativas com números desatualizados (Bloco 5)
4. Power BI em si — não tem bloqueio técnico, só não foi iniciado (Bloco 6)

---

*Atualizado 2026-07-12. Changelog de 07-10 baseado em auditoria de código; changelog de 07-12 (municipios_ref, UF, data_root) inclui validação em produção confirmada pelo autor via execução real do pipeline no DBeaver — não apenas revisão de arquivo.*
