# Enforcement Gap Monitoring System (EGMS)

Pipeline DuckDB + SQL + R que cruza desmatamento (PRODES/INPE) com fiscalização ambiental (IBAMA) na Amazônia Legal, produzindo o **Enforcement Gap Score (EGS)** — um índice de município-ano que mede o desequilíbrio entre pressão de desmatamento e resposta institucional.

Autor: Diogo Grieco.

---

## Stack

- **DuckDB** — motor de consulta / armazenamento (`project2.duckdb`)
- **SQL** — pipeline em 4 arquivos (`01_staging.sql` → `04_export.sql`)
- **R (tidyverse)** — exploração e validação dos dados brutos (`exploring_script.R`)
- **Power BI** — dashboard (consome os parquets gerados por `04_export.sql`)

O pipeline roda igualmente via DBeaver, DuckDB CLI, ou o pacote `duckdb`/`DBI` em R — nenhuma etapa depende do diretório de trabalho do cliente (ver "Configuração" abaixo).

---

## Estrutura de pastas esperada

```
project2/
├── 01_staging.sql
├── 02_marts.sql
├── 03_analytics.sql
├── 04_export.sql
├── exploring_script.R
├── project2.duckdb          (gerado ao rodar o pipeline)
├── data_prodes/              (dados brutos — não versionado)
│   └── terrabrasilis_legal_amazon_*.csv
├── data_ibama/                (dados brutos — não versionado)
│   └── auto_infracao_ano_*.csv
├── data_ibge/                 (dados brutos — não versionado)
│   └── municipios.json
├── data_ipca/                 (dados brutos — não versionado)
│   └── sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv
└── output/                    (gerado por 04_export.sql — não versionado)
    ├── pbi_egs_final.parquet
    ├── pbi_ranking_absolute_gap.parquet
    ├── pbi_ranking_measured_gap.parquet
    └── pbi_annual_summary.parquet
```

As pastas `data_*/` e `output/` **não são versionadas** (ver `.gitignore` abaixo) — são grandes, de download manual, e regeneráveis a partir das fontes primárias.

---

## Fontes de dados e instruções de download

| Pasta | Fonte | Onde baixar |
|---|---|---|
| `data_prodes/` | PRODES/INPE, desmatamento anual por município na Amazônia Legal | [TerraBrasilis](https://terrabrasilis.dpi.inpe.br/) — exportar CSV agregado por município-ano |
| `data_ibama/` | IBAMA, autos de infração ambiental (um CSV por ano) | [dadosabertos.ibama.gov.br](https://dadosabertos.ibama.gov.br/) — dataset "Fiscalização - auto de infração" |
| `data_ibge/` | IBGE, referência de município/UF | API de localidades: `https://servicodados.ibge.gov.br/api/v1/localidades/municipios` — baixar o JSON (fetch automatizado não funcionou de forma confiável neste projeto; baixar via navegador e salvar como `municipios.json`) |
| `data_ipca/` | IBGE/Sidra, índice IPCA mensal (deflator) | [Sidra, tabela 1737, variável 2266](https://sidra.ibge.gov.br/tabela/1737) — série Brasil, formato CSV largo (mês × ano) |

Os nomes de arquivo esperados por `01_staging.sql` usam wildcard (`*`) para PRODES e IBAMA — múltiplos CSVs na mesma pasta são concatenados automaticamente. O CSV do IPCA e o JSON do IBGE têm nome exato esperado (ver caminho completo no próprio `01_staging.sql`); ajuste o nome do arquivo real para bater, ou edite o `read_csv`/`read_json_auto` correspondente.

---

## Configuração — ponto único (`data_root`)

O topo de `01_staging.sql` define uma variável de sessão do DuckDB que é a **única linha que precisa ser editada** para rodar o pipeline em qualquer máquina:

```sql
SET VARIABLE data_root = 'C:/Users/diogo/projects/project2';  -- editar aqui
```

Todos os `read_csv`/`read_json_auto` do pipeline usam `getvariable('data_root') || '/...'` em vez de paths relativos ou absolutos fixos. Isso resolve igual em DBeaver, DuckDB CLI e R — nenhum dos três compartilha necessariamente o mesmo diretório de trabalho de processo.

---

## Como rodar

1. Baixe os 4 conjuntos de dados brutos (ver tabela acima) para as pastas `data_*/` correspondentes.
2. Edite `data_root` no topo de `01_staging.sql` para o caminho local do seu clone.
3. Rode os arquivos SQL em ordem, validando os checks ao final de cada um antes de seguir para o próximo:
   ```
   01_staging.sql    → ingestão bruta (staging) + municipality_ref + ipca_deflator
   02_marts.sql      → limpeza e tipagem (marts)
   03_analytics.sql  → cálculo do EGS, streaks, rankings (analytics)
   04_export.sql     → materializa parquets em output/ para o Power BI
   ```
   No DBeaver: abrir o script, associar à conexão do `project2.duckdb`, `Execute SQL Script` (Alt+X) roda o arquivo inteiro, incluindo os blocos `== CHECKS ==` ao final de cada etapa.
4. Confira os checks — todos devem retornar os valores esperados documentados nos comentários de cada arquivo (ex.: `n_municipality_ref = 5.571`, `missing_uf = 0`). Se algum check falhar, não prossiga para a etapa seguinte sem investigar.
5. (Opcional) Abra `exploring_script.R` no RStudio para reproduzir a validação exploratória dos dados brutos — o script tem `stopifnot()` em cada etapa crítica e serve como documento auditável das decisões analíticas (filtros do IBAMA, escolha da coluna de data, análise de lag, sensibilidade do join).
6. Aponte o Power BI para os 4 arquivos parquet em `output/`.

---

## `.gitignore` recomendado

```
# dados brutos — grandes, download manual, regeneráveis
data_prodes/
data_ibama/
data_ibge/
data_ipca/

# saída do pipeline — regenerável a partir do banco
output/

# banco DuckDB local
project2.duckdb
*.wal
```

---

## Documentação do projeto

- `project2_session_reference_v5.md` — referência técnica completa: decisões metodológicas, estrutura de dados, resultados confirmados em produção. Prosa em português, identificadores citados em inglês (nomes reais do código — ver nota de nomenclatura no topo do documento).
- `p2_technical_fixes.txt` — histórico de bugs identificados e correções aplicadas (16 fixes documentados), incluindo os dois itens ainda abertos (Fix 4, Fix 5 — problemas sistêmicos de escopo de dados, não bugs de código) e o Fix 16 (tradução completa do pipeline para inglês + rename `tipo_egs`→`gap_type`).
- `p2_next_steps.md` — plano de execução por bloco, com status atualizado a cada sessão de trabalho.
- `p2_narrative_draft.md` / `p2_results_narrative_draft.md` — narrativa de portfólio (o que o sistema faz, o que os dados mostram), com números re-ancorados no pipeline confirmado em produção.
- `exploring_script_explained.md` / `sql_explained.md` — guia comentado, linha a linha, do `exploring_script.R` e dos 4 arquivos SQL: o que cada trecho faz, por que, mecânica de R/tidyverse e DuckDB/SQL envolvida, e alternativas possíveis. Material de estudo, não faz parte do pipeline executável.

---

## Limitações conhecidas (resumo — detalhamento em `p2_technical_fixes.txt`)

- **PRODES ≠ desmatamento ilegal.** O índice não distingue supressão autorizada (AUTEX/DOF) de desmatamento sem autorização. Um caso específico (Barra do Bugres/MT) foi verificado via pesquisa externa e tem alta proporção de desmatamento legalmente autorizado — ver Fix 4.
- **Enforcement estadual não capturado.** O dataset cobre apenas autos federais (IBAMA); secretarias estaduais (SEMAS-PA, SEMA-MT, etc.) não estão incluídas — ver Fix 5.
- **Amazônia Legal apenas.** Extensão a outros biomas requer join espacial (coordenadas GPS do IBAMA × polígonos de bioma) em vez do join tabular por geocode atual — ver Fix 6.
- **Quebras estruturais do PRODES — investigadas, sem achado.** A série de `area_km2` por ano (2008–2025) foi checada contra a taxa oficial do INPE/PRODES em 4 anos-âncora e bateu dentro de poucos pontos percentuais em todos eles; a trajetória completa (alta 2008, fundo 2012, pico 2019-2022, queda 2023-2025) é consistente com história documentada de desmatamento e política de fiscalização (Resolução CMN nº 3.545/2008), não com mudança de sensor ou de unidade mínima de mapeamento do INPE. Ver Fix 15.
- **`exploring_script.R` não tem o mesmo tratamento de portabilidade do SQL.** Usa paths relativos fixos (`PATH_IBAMA <- "data_ibama"`, etc.) que dependem do working directory do processo R — pode falhar (`list.files()` retornando vazio) se o script não for rodado a partir da raiz do projeto. Não corrigido ainda; ver nota em Fix 14.
