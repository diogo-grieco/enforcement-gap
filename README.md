# Enforcement Gap Monitoring System (EGMS)

Pipeline DuckDB + SQL + R que cruza desmatamento (PRODES/INPE) com fiscalização ambiental federal (IBAMA) na Amazônia Legal, produzindo o **Enforcement Gap Score (EGS)** (um índice de município-ano que mede o desequilíbrio entre pressão de desmatamento e resposta institucional federal) e um ranking municipal consolidado (`egs_ranking`).

Autor: Diogo Grieco.

---

## Stack

- **DuckDB**: motor de consulta / armazenamento (`project2.duckdb`)
- **SQL**: pipeline em 4 arquivos (`pipeline/01_staging.sql` → `pipeline/04_export.sql`)
- **R (tidyverse)**: validação paralela dos dados brutos (`exploration/`) e suíte de visualização (`viz/`)
- **Power BI**: dashboard opcional (consome os parquets gerados por `04_export.sql`)

O pipeline roda igualmente via DBeaver, DuckDB CLI, ou o pacote `duckdb`/`DBI` em R. Nenhuma etapa depende do diretório de trabalho do cliente (ver "Configuração" abaixo).

---

## Estrutura de pastas esperada

```
project2/
├── README.md                  (cópia deste arquivo na raiz do repo)
├── pipeline/
│   ├── 01_staging.sql
│   ├── 02_marts.sql
│   ├── 03_analytics.sql
│   └── 04_export.sql
├── exploration/                (validação paralela em R, roda direto sobre os CSVs brutos)
│   └── exploring_script.R
├── viz/                         (suíte de visualização; ver viz/README.md)
│   ├── 00_setup.R, 00_build_mesh.R, 01_maps.R … 07_offender_network.R
│   └── README.md
├── deliverables/
│   ├── EGMS_01_resumo_executivo.docx
│   ├── EGMS_02_writing_sample.docx
│   └── EGMS_03_relatorio_estendido.docx
├── project2.duckdb              (gerado ao rodar o pipeline, não versionado)
├── data/
│   ├── data_prodes/
│   │   └── terrabrasilis_legal_amazon_*.csv
│   ├── data_ibama_public/       (13 de 84 colunas; CPF/CNPJ pseudonimizado; ver README na pasta)
│   │   └── auto_infracao_ano_*.csv
│   ├── data_ibge/
│   │   ├── municipios.json
│   │   ├── municipality_area_2025.csv
│   │   └── malha_772_amazonia_legal_simplificada.geojson   (gerado por viz/00_build_mesh.R)
│   └── data_ipca/
│       └── sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv
└── output/
    ├── parquets/                (gerado por 04_export.sql)
    │   ├── egs_final.parquet
    │   ├── egs_ranking.parquet
    │   └── annual_summary.parquet
    └── visualizations/          (PNG/GIF gerados pela suíte viz/)
```

`data/`, os parquets finais em `output/parquets/`, `output/visualizations/` e `deliverables/` **são versionados**: é o que torna o repositório reprodutível a partir de um clone limpo e legível diretamente no GitHub, sem depender de um download externo. `data/data_ibama_public/` é uma versão derivada do dado bruto do IBAMA sem identificação do autuado (ver seção "Dados do IBAMA e privacidade" abaixo); o CSV original com nome/CPF/CNPJ nunca é versionado. A malha antes da simplificação, caches intermediários (`output/parquets/viz_*.parquet`) e o banco `project2.duckdb` não são versionados, são grandes e regenerados por um rerun local.

---

## Fontes de dados e instruções de download

| Pasta | Fonte | Onde baixar |
|---|---|---|
| `data/data_prodes/` | PRODES/INPE, desmatamento anual por município na Amazônia Legal | [TerraBrasilis](https://terrabrasilis.dpi.inpe.br/): exportar CSV agregado por município-ano |
| `data/data_ibama_public/` | IBAMA, autos de infração ambiental (um CSV por ano, versão derivada sem identificação do autuado) | Derivado de [dadosabertos.ibama.gov.br](https://dadosabertos.ibama.gov.br/), dataset "Fiscalização - auto de infração"; script de derivação em `data/data_ibama_public/README.md` |
| `data/data_ibge/` (referência) | IBGE, referência de município/UF | API de localidades: `https://servicodados.ibge.gov.br/api/v1/localidades/municipios`: baixar o JSON via navegador e salvar como `municipios.json` |
| `data/data_ibge/` (áreas) | IBGE, Malha Municipal Digital / Áreas Territoriais 2025 | [ibge.gov.br → áreas dos municípios](https://www.ibge.gov.br/geociencias/organizacao-do-territorio/estrutura-territorial/15761-areas-dos-municipios.html), arquivo `AR_BR_RG_UF_RGINT_RGI_MUN_2025.xls`. Converter uma vez para CSV (`municipality_area_2025.csv`); o `01_staging.sql` espera `delim = ','`, se converter com Excel/LibreOffice (que tende a usar `;`), ajustar o delim no `read_csv` correspondente |
| `data/data_ipca/` | IBGE/Sidra, índice IPCA mensal (deflator) | [Sidra, tabela 1737, variável 2266](https://sidra.ibge.gov.br/tabela/1737): série Brasil, formato CSV largo (mês × ano) |

Os nomes de arquivo esperados por `01_staging.sql` usam wildcard (`*`) para PRODES e IBAMA: múltiplos CSVs na mesma pasta são concatenados automaticamente. IPCA, JSON do IBGE e CSV de áreas têm nome exato esperado (ver caminho completo no próprio `01_staging.sql`).

---

## Dados do IBAMA e privacidade

Os autos de infração do IBAMA, como publicados, trazem nome e CPF/CNPJ do autuado. Como este repositório é público, `data/data_ibama_public/` mantém apenas as 13 das 84 colunas brutas efetivamente usadas em algum ponto do pipeline ou da suíte `viz/` (município, datas, valor da multa, tipo e código da infração, status, embargo/apreensão). `NOME_INFRATOR` é descartado (nunca é lido em nenhum script). `CPF_CNPJ_INFRATOR` é substituído por um **identificador substituto aleatório e estável** (`pid_` + 16 dígitos hexadecimais sorteados, um por autuado): o mesmo autuado recebe sempre o mesmo `pid_`, então toda contagem que depende de identidade (curva de Lorenz, rede de infratores multi-município) é idêntica ao dado original. O mapa `CPF/CNPJ → pid_` é gerado uma única vez, mantido apenas localmente e **nunca versionado**. O CSV original com nome/CPF/CNPJ nunca é versionado neste repositório.

**O que essa substituição garante, e o que ela não garante.** Como o substituto é aleatório (não derivado do próprio CPF/CNPJ), **o `pid_` não é reversível**: não existe salt, chave ou função conhecida que, aplicada a um CPF candidato, reproduza o identificador publicado. Uma versão anterior deste repositório usava `sha256(salt + CPF/CNPJ)` com o salt publicado no próprio README, o que *era* reversível por força bruta; essa versão foi substituída e nunca chegou a ser commitada: `data/data_ibama_public/` aparece pela primeira vez no repositório já com o substituto aleatório.

O que a substituição **não** faz é tornar a linha anônima. As outras 12 colunas são reproduzidas sem alteração a partir do CSV original do IBAMA, que é **público e traz `NOME_INFRATOR` e `CPF_CNPJ_INFRATOR`**. A combinação (`COD_MUNICIPIO`, `DAT_HORA_AUTO_INFRACAO`, `VAL_AUTO_INFRACAO`) identifica unicamente **74,3% das 309.116 linhas**, e `CD_TERMOS_EMBARGOS`/`CD_TERMOS_APREENSAO` são números de termo consultáveis nos registros do próprio IBAMA. Quem baixar a fonte original consegue, portanto, refazer o vínculo linha a linha, e, por transitividade, reconstruir o mapa `pid_ → CPF/CNPJ` para boa parte da base.

Isso é uma consequência deliberada do desenho, não uma falha de execução: **o dado-fonte já é público com a identificação**, e esta pasta é uma cópia reduzida dele, não uma desidentificação. O propósito do `pid_` é permitir que as contagens por identidade (Lorenz, Gini, rede de infratores) sejam reproduzíveis **sem que este repositório redistribua CPF/CNPJ**, não impedir a reidentificação de um dado que o órgão publica. Quem precisar de um dado efetivamente anonimizado deve tratar esta pasta como o que ela é: um recorte de dado administrativo público.

**Nota de reprodutibilidade:** por ser aleatório, o pseudônimo **não é bit-reproduzível**. Quem rerodar o script de derivação sobre o dado bruto do IBAMA vai gerar `pid_` diferentes dos publicados aqui, e a coluna não será comparável célula a célula com a deste repositório. Isso é deliberado (é o que impede a reversão) e não afeta nenhum resultado: tudo que o pipeline e a suíte `viz/` calculam a partir dessa coluna depende apenas de *igualdade preservada* (mesmo autuado, mesmo símbolo), não do valor em si. A curva de Lorenz, o índice de Gini e a rede de infratores multi-município reproduzem identicamente sob qualquer rodada do script.

---

## Configuração, ponto único (`data_root`)

O topo de `01_staging.sql` define uma variável de sessão do DuckDB que é a **única linha que precisa ser editada** para rodar o pipeline em qualquer máquina:

```sql
SET VARIABLE data_root = 'C:/Users/diogo/projects/project2';  -- editar aqui
```

Todos os `read_csv`/`read_json_auto` do pipeline usam `getvariable('data_root') || '/...'`, **inclusive os `COPY ... TO` e o check de `04_export.sql`**, essa linha é, de fato, a única que precisa ser editada em todo o pipeline. Como a variável é de sessão, rode os quatro arquivos na mesma conexão (no DBeaver: mesma aba/conexão do `project2.duckdb`).

**Versão do motor.** O pipeline foi rodado e verificado em DuckDB 1.5.x (pacote R `duckdb` 1.5.4.3 e CLI 1.5.5). O `quote = '"'` declarado no `read_csv` do IBAMA em `01_staging.sql` é o que torna a leitura independente da versão: sem ele, DuckDB a partir de 1.2.0 aborta em 86 linhas que trazem `;` dentro de aspas.

---

## Como rodar

1. Um clone do repositório já contém todos os dados brutos versionados em `data/`, nenhum download é necessário para reproduzir os resultados publicados. Para atualizar com dados mais recentes, baixe os 5 conjuntos (ver tabela acima) para as pastas `data_*/` correspondentes.
2. Edite `data_root` no topo de `01_staging.sql` para o caminho local do seu clone.
3. Rode os arquivos SQL em ordem, validando o bloco de checks ao final de cada um antes de seguir:
   ```
   01_staging.sql    → ingestão bruta apenas (5 tabelas *_raw, tudo VARCHAR, sem filtro)
   02_marts.sql      → limpeza, tipagem e padronização (ibama_clean, prodes_clean,
                        municipality_ref, municipality_area, ipca_annual)
   03_analytics.sql  → índices derivados: deflator IPCA, EGS unificado (fórmula única
                        com piso no denominador), egs_ranking (média 0-fill 18 anos,
                        média 3 anos, slope, pct_desmatado), annual_summary
   04_export.sql     → materializa 3 parquets em output/parquets/
   ```
   No DBeaver: abrir o script, associar à conexão do `project2.duckdb`, `Execute SQL Script` (Alt+X) roda o arquivo inteiro, incluindo o bloco `== CHECKS ==` ao final.
4. Confira os checks: cada arquivo termina em **uma única query consolidada** que retorna `check_name | actual | expected | status` (56 checks no total, entre os 4 arquivos; falhas aparecem no topo do grid). Qualquer linha com `status = failed` deve ser investigada antes de prosseguir, ver a nota de reprodutibilidade acima antes de assumir que é um bug. A pasta `output/parquets/` precisa existir antes de rodar o `04` (o `COPY` não cria diretórios).
5. Rode a suíte `viz/` (ver `viz/README.md`) para gerar os gráficos e mapas a partir dos parquets, ou aponte o Power BI para os 3 arquivos em `output/parquets/`.
6. (Opcional) Rode `exploration/exploring_script.R` para reproduzir, em R, a validação independente das mesmas decisões (filtro de desmatamento, lag do join IBAMA/PRODES, sensibilidade do limiar, EGS reconstruído), é a checagem cruzada da implementação SQL, não uma etapa obrigatória do pipeline.

---

## Datas de download e reprodutibilidade

Os valores esperados nos blocos de check (`n_ibama = 60707`, `total_fines = 26814492927`, `n_absolute_gap = 3063`, etc.) são uma fotografia dos dados na data em que foram baixados, **não são invariantes da fonte**. IBAMA pode revisar retroativamente seus CSVs de autos de infração (cancelamentos, correções, novos registros); PRODES publica estimativa preliminar e consolida o ano mais recente meses depois. Quem baixar os dados de novo, hoje ou no futuro, pode ver checks `failed` sem que haja bug algum no pipeline, só dado mais recente que o snapshot documentado aqui.

| Fonte | Data do snapshot usado | Observação |
|---|---|---|
| PRODES (`data/data_prodes/`) | 25/04/2026 (no próprio nome do arquivo) | 2025 é o ano mais recente do painel e pode não estar consolidado; ver nota "último ano sujeito a revisão" |
| IBAMA (`data/data_ibama_public/`) | 25/04/2026 | O nome dos arquivos (`auto_infracao_ano_*.csv`) não carrega a data de download; ela fica registrada aqui e na tabela de fontes do relatório estendido |
| IBGE, referência (`municipios.json`) | 12/07/2026 | Download manual via navegador (API não respondeu de forma confiável neste projeto) |
| IBGE, áreas territoriais (`municipality_area_2025.csv`) | 20/07/2026 | Convertido de `.xls` para CSV; ver nota de delimitador em `01_staging.sql` |
| IBGE/Sidra, IPCA | 10/07/2026 (no próprio nome do arquivo) | Série Brasil, tabela 1737, variável 2266, formato largo |

Antes de comparar um check `failed` com o pipeline, confirme se algum dos 5 arquivos foi rebaixado depois dessas datas. Se sim, o esperado do check é o que precisa ser atualizado, não o SQL.

---

## `.gitignore`

O arquivo [`.gitignore`](.gitignore) na raiz é a fonte única; cada regra traz no próprio arquivo o comentário que a justifica. Em resumo, ficam de fora: artefatos do RStudio; o banco `project2.duckdb`, o binário do CLI e os `.wal`; o dado bruto do IBAMA com identificação do autuado (`data/data_ibama/`); a malha antes da simplificação; os caches intermediários da suíte `viz/`; e o material interno do processo de pesquisa (`references/`, `CHANGELOG.md`).

Dados brutos (`data/data_prodes/`, `data/data_ibama_public/`, `data/data_ibge/`, `data/data_ipca/`) e os parquets finais (`output/parquets/`) são versionados: é o que torna o repositório reprodutível a partir de um clone limpo, sem depender de um download externo. `output/visualizations/` e `deliverables/` também são versionados, os resultados e os textos finais ficam legíveis direto no GitHub, além do depósito com DOI no Zenodo/preprint.

---

## Licenças e citação

O código-fonte (`pipeline/`, `viz/`, `exploration/`) está sob licença **MIT**, ver [`LICENSE`](LICENSE). Os dados derivados, parquets, visualizações e os três relatórios em `deliverables/` estão sob **Creative Commons Attribution 4.0 (CC BY 4.0)**, ver [`LICENSE-DATA.md`](LICENSE-DATA.md). Para citar este trabalho, ver [`CITATION.cff`](CITATION.cff).

Mudanças de substância entre versões, incluindo as que alteraram números publicados, estão resumidas na seção "Registro de mudanças" de [`deliverables/EGMS_03_relatorio_estendido.docx`](deliverables/EGMS_03_relatorio_estendido.docx).

---

## Documentação do projeto

- `deliverables/EGMS_01_resumo_executivo.docx`: síntese de 2 a 3 páginas.
- `deliverables/EGMS_02_writing_sample.docx`: texto autoral completo, com decisões metodológicas, validação, resultados e limites.
- `deliverables/EGMS_03_relatorio_estendido.docx`: apêndice técnico completo, com todas as decisões e o teste empírico correspondente.
- `viz/README.md`: como rodar a suíte de visualização.

---

## Limitações conhecidas (resumo, detalhamento em `deliverables/EGMS_03_relatorio_estendido.docx`)

- **O índice mede lacuna de fiscalização *federal*.** Só autos do IBAMA entram como resposta; aparatos estaduais ativos (ex.: SEMAS-PA, IPAAM-AM) não são capturados, um EGS alto é compatível com ausência real, substituição estadual, ou presença federal sem efeito.
- **PRODES ≠ desmatamento ilegal.** O índice não distingue supressão autorizada (AUTEX/DOF) de ilegal, caso verificado: Barra do Bugres/MT.
- **Resposta = autos lavrados.** Embargos, apreensões, ação penal e arrecadação efetiva das multas não entram.
- **EGS é ordinal na prática.** A ordenação é robusta (testada por sensibilidade); distâncias entre scores não têm interpretação direta.
- **Amazônia Legal apenas**; extensão a outros biomas ou jurisdições exige novo join espacial.
- **Último ano sujeito a revisão**: o dado PRODES 2025 pode não estar consolidado; a média de 3 anos o inclui, com essa ressalva.
