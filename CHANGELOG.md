# Changelog

Mudanças de substância no EGMS. Correções de redação e formatação não estão listadas.

O formato segue, de forma simplificada, [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

## [1.0.0] — 2026-07-27

Primeira versão pública completa. Duas mudanças abaixo alteram números publicados
anteriormente: quem tiver um clone, um texto ou uma citação anterior a esta data deve
tratar os valores antigos como substituídos.

### Alterado

- **Universo do painel: 805 → 772 municípios.** O export municipal do TerraBrasilis
  rotulado `legal_amazon` traz 805 geocodes, mas 33 deles ficam em estados **fora** da
  Amazônia Legal (GO 18, PI 6, MS 5, BA 4), todos com área desmatada zero em todos os 18
  anos. 805 − 33 = 772, exatamente a contagem oficial da Amazônia Legal (IBGE). O filtro
  passou a ser aplicado em `pipeline/02_marts.sql`.

  Números afetados:

  | | antes (805) | agora (772) |
  |---|---|---|
  | Municípios | 805 | 772 |
  | Município-anos | 14.490 | 13.896 |
  | `no_pressure` | 8.142 (56,2%) | 7.548 (54,3%) |
  | `absolute_gap` | 3.063 (21,1%) | 3.063 (22,0%) |
  | `measured_gap` | 3.285 (22,7%) | 3.285 (23,6%) |
  | Gini (multas/infrator) | 0,803 | 0,801 |
  | `pct_desmatado` mediana / p75 | 0,97% / 3,19% | 1,10% / 3,38% |

  **O ranking não mudou**: os 33 municípios removidos tinham EGS 0 e ocupavam o fim da
  lista. Top 20, casos-âncora e todas as conclusões substantivas permanecem idênticos.

- **Pseudonimização do IBAMA: hash → substituto aleatório.** A versão anterior derivava
  `CPF_CNPJ_INFRATOR` de `sha256(salt + valor)`, com o salt escrito no próprio README da
  pasta. Como CPF/CNPJ têm baixa entropia, isso permitia reverter o pseudônimo por força
  bruta em minutos. Agora cada autuado recebe um identificador aleatório (`pid_` + 16
  hex), com o mapa mantido apenas localmente e nunca versionado. Ver
  `data/data_ibama_public/README.md`.

  Registro, para quem for auditar o histórico: **a versão reversível nunca chegou a ser
  commitada**. `data/data_ibama_public/` aparece pela primeira vez no repositório já com
  o substituto aleatório, e não há nenhuma ocorrência de `sha256`, `hashlib` ou do salt
  em nenhum commit — logo, não é possível recuperar o pseudônimo antigo do histórico do
  git e alinhá-lo ao novo por posição de linha.

  Consequência: os valores de `pid_` mudaram por completo em relação à versão anterior,
  e não são bit-reproduzíveis entre execuções do script de derivação. Nenhum resultado é
  afetado — tudo que depende dessa coluna usa apenas igualdade preservada.

  **O que isso não resolve, dito explicitamente:** o `pid_` deixou de ser reversível,
  mas a tabela publicada continua religável ao CSV original do IBAMA (público, com
  nome), porque as outras 12 colunas são cópias literais — 74,3% das linhas são únicas
  por (município, data do auto, valor da multa). A redação que afirmava "identidade não
  recuperável a partir do dado publicado" foi corrigida em toda parte: esta pasta é um
  recorte de dado administrativo público, não uma anonimização.

### Adicionado

- `LICENSE` (MIT, código), `LICENSE-DATA.md` (CC BY 4.0, dados e documentos) e
  `CITATION.cff`.
- Check `out_of_scope_geocodes_prodes` (esperado: 33) em `pipeline/01_staging.sql`:
  vigia a **fonte**, disparando se um download futuro do PRODES mudar quais municípios
  são entregues. Total de verificações: 54 → **55**.
- `viz/00_load_ibama_clean.R` passou a ser versionado (era exigido por
  `04_raw_ibama.R` e `07_offender_network.R`, mas estava fora do controle de versão —
  um clone limpo não rodava esses dois scripts).

### Corrigido

- **O pipeline voltou a rodar em versões atuais do DuckDB.** `01_staging.sql` lia os
  CSVs do IBAMA sem declarar `quote`. O sniffer amostra só o primeiro arquivo do glob
  (2008, sem nenhum campo entre aspas), inferia `quote = (empty)` e, a partir do
  DuckDB 1.2.0, abortava com erro fatal nas **86 linhas de 2019–2025 que têm `;`
  dentro de aspas** (códigos de termo de embargo múltiplos). Testado: falha em 1.2.2,
  1.3.2, 1.4.1 e 1.5.5; passava só em ≤ 1.1.3, por sorte do sniffer. Com
  `quote = '"'` explícito, os 55 checks passam em qualquer versão e a contagem é a
  mesma (309.116).
- **Âncora do PRODES 2024.** A validação comparava o painel (6.263 km²) à estimativa
  **preliminar** de 6.288 km², divulgada em nov/2024 e superada pela **taxa
  consolidada de 6.518 km²**, que é a base que o próprio INPE usa na nota técnica de
  out/2025. O desvio correto é **−3,9%**, não −0,4%. Os quatro âncoras passaram a ser
  reportados individualmente, sem limiar de aprovação, com a ressalva de que soma
  municipal e taxa estadual não são o mesmo objeto. O valor 5.731 km² para 2025, que
  aparecia como piso de um intervalo, foi removido por não ter fonte localizável.
- **Overlap com a Portaria GM/MMA 1.202/2024: 8/20 → 9/20.** Recomputado contra o
  Anexo I (81 municípios). Coincidem Mojuí dos Campos, Maués, Santa Maria das
  Barreiras, Itupiranga, Cumaru do Norte, Jacareacanga, Medicilândia, Prainha e
  Santana do Araguaia — todos entre as posições 8 e 17. **Nenhum dos sete primeiros
  do ranking consta da lista**, e nenhum dos 20 está no Anexo II. O texto passou a
  nomear os nove e a discutir a distribuição, que diz mais que a contagem.
- **`exploration/exploring_script.R` migrado para 772.** O script continuava operando
  sobre os 805 do export bruto (`stopifnot(... == 805)`, `N_NO_PRESSURE <- 8142`),
  enquanto o SQL já validava 772 — as duas implementações deixaram de se espelhar e
  nenhum check detectava isso. Recebeu o mesmo filtro de escopo por prefixo de
  geocode, constantes recalculadas e uma guarda nova para o total de geocodes
  descartados.
- **Números do painel de 805 remanescentes**: "3.392 município-anos (23,4% do painel)"
  → **24,4%** (o 23,4% era sobre 14.490); Spearman da sensibilidade de limiar 0,985 →
  **0,9868** (1 km² vs 6,25 ha) e **0,9866** (1 km² vs sem limiar), recomputados sobre
  os 772; comentário do `03_analytics.sql` que ainda citava 56,2%.
- **Contagem de checks**: o writing sample dizia "55 verificações (7 na ingestão, 26,
  20, 1)", que soma 54. São **8** em staging.
- **Afirmações sobre o próprio processo**: "quatro auditorias" e "54/54" → seis
  auditorias e 55 checks, nos três documentos; a tabela de Registro de Mudanças passou
  a incluir as rodadas 5 e 6.
- **A frase que dizia que o registro de auditoria "está versionado no repositório"**
  contradizia o `.gitignore` e este próprio arquivo. Reescrita: o resumo está aqui e na
  seção "Registro de mudanças" do relatório estendido; o histórico linha a linha é
  documentação interna.
- **Tabela 2 do writing sample** reportava `n/d` para o EGS de 3 anos e a tendência de
  Cumaru do Norte, dados que existem no parquet: **1,223** e **+0,032** — o município
  está piorando, e a tabela escondia justamente isso.
- **Legenda do gráfico log-log**: a diagonal era descrita como "a fronteira de resposta
  proporcional (EGS = 1)". Não é: a reta é `multas = 10⁵ × km²`, uma referência
  escolhida, e a fronteira EGS = 1 depende também do número de autos, que não está nos
  eixos — além de o gráfico agregar 18 anos, enquanto o EGS é anual. Corrigido nas duas
  legendas e no comentário do código.
- **Portaria 1.717/2026** era descrita como "ainda não obtida"; a lista é pública (89
  municípios em AC, AM, MA, MT, PA, RO e RR).
- **26 referências novas** (11 no writing sample, 15 no relatório estendido) para
  afirmações externas que antes não tinham entrada na lista: INPE (nota técnica),
  Operação Curupira, Operação Tamoiotatá, operação do IBAMA em Apuí, Operação Máscara
  Rural, orçamento e efetivo do IBAMA, SEMA-MT/Barra do Bugres, Portaria 1.717 e as
  fontes dos casos municipais. A entrada da Portaria 1.202 ganhou data completa e
  referência do DOU (ed. 220, seção 1, p. 121).
- **Verificação externa por município** incorporada ao texto: em quatro dos vinte
  primeiros, parte do desmatamento é supressão licenciada ou o território está sob
  regime especial — Oriximiná (Flona Saracá-Taquera, 12.639 ha sob licença de
  operação), Autazes (potássio licenciado pelo IPAAM), Porto de Moz (Resex federal) e
  Jacareacanga (TI Munduruku). Nenhum invalida o índice; todos qualificam a leitura.
- **Alegação de privacidade** reescrita — ver a seção da pseudonimização acima.
- Rótulos das figuras: sufixos de escala em inglês (`10K`, `1M`, `1B`) → `mil`, `mi`,
  `bi`; separador decimal dos eixos contínuos e da legenda do ridgeline em vírgula;
  separador de milhar nos eixos; setas `->` → `→`.
- `viz/README.md`: `geobr` e `rmapshaper` faltavam na lista de instalação, embora
  `00_build_mesh.R` dependa dos dois.
- `CITATION.cff`: data alinhada ao release (27/07) e licença passou a declarar
  **MIT e CC-BY-4.0**, e não só MIT — quem cita pelo arquivo lia o repositório inteiro
  como MIT.
- `pipeline/04_export.sql` não tem mais caminhos absolutos: os três `COPY ... TO` e o
  check de staleness usam `getvariable('data_root')`. Agora a linha `data_root` no topo
  de `01_staging.sql` é, de fato, a única edição necessária para rodar o pipeline em
  qualquer máquina.
- Figura "mix de instrumentos": rótulo `seizure` (inglês) → `apreensão`.
- Figura "taxa de cancelamento por estado": deixou de exibir BA, GO e MS, consequência
  do filtro de escopo acima.
- `seed` fixo nos rótulos `ggrepel` (log-log e quadrante): as figuras agora são
  byte-idênticas entre execuções, e a versão publicada coincide com a embutida nos
  relatórios.
- Separador decimal das figuras em padrão brasileiro (vírgula); `km2` → `km²`;
  data de acesso do IBAMA nas referências (NBR 6023).

---

## Versões anteriores

O histórico detalhado das versões v1–v5 do pipeline e das quatro primeiras auditorias
adversariais está resumido em `deliverables/EGMS_03_relatorio_estendido.docx`, seção
"Registro de mudanças". O registro linha a linha é documentação interna de
desenvolvimento e não faz parte deste repositório.
