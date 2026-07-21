# EGMS como MVP — horizonte de um sistema nacional, multi-bioma e multi-jurisdição

**Status deste documento:** rascunho de horizonte, não plano de execução. Descreve o que falta para uma versão do EGMS que monitore todos os biomas via coordenadas/GIS (em vez de geocode IBGE) e capture fiscalização não federal (estadual, municipal, ICMBio e demais órgãos com prerrogativa de multa), além do federal (IBAMA) já coberto. Não substitui o `sql_technical_fixes.md`, que trata do MVP atual.

---

## 1. O que o MVP já resolve — surpreendentemente mais do que parece

Antes de listar lacunas, vale registrar o que a pesquisa desta sessão encontrou: três das premissas mais caras de um sistema "em grande escala" já têm resposta parcial ou total, e não exigem reescrever a arquitetura atual.

**"Todos os biomas" já tem fonte de dado oficial.** O PRODES foi expandido em 2018 para o Cerrado e, em 2022, passou a cobrir sistematicamente Pantanal, Pampa, Mata Atlântica e Caatinga — o "PRODES Brasil", integrado ao programa BiomasBR do INPE. A pergunta não é mais "onde arranjar dado de desmatamento fora da Amazônia Legal" — é "trocar o filtro de bioma na ingestão", não trocar de fonte.

**O salto para coordenadas é mais barato do lado federal do que parece.** O dataset bruto do IBAMA — o mesmo que o pipeline atual já lê, mas usa só `COD_MUNICIPIO` — já tem campos de latitude/longitude por auto de infração (`NUM_LATITUDE_AUTO`, `NUM_LONGITUDE_AUTO`) e até uma geometria WKT (`DS_WKT`). O trabalho de geolocalizar o lado federal está, em boa parte, feito — só não está sendo usado.

**ICMBio já publica dado aberto geoespacializado.** Desde agosto de 2023, o ICMBio disponibiliza autos de infração com dados completos dos autuados e os polígonos das áreas embargadas, atualizado mensalmente, com uma base histórica 2009–2021 já aberta (mais de 9 mil multas, R$ 3 bilhões). É a fonte de menor esforço de todo o horizonte — mais barata que IBAMA foi, porque já nasce geoespacializada.

**O motor não precisa trocar.** DuckDB tem uma extensão espacial madura (`ST_Contains`, tipos `GEOMETRY`/`POLYGON`, e desde a versão 1.3 um operador dedicado de *spatial join* otimizado para exatamente o problema "quais pontos caem em quais polígonos"). Migrar para PostGIS deixa de ser um requisito técnico — é uma opção, não uma necessidade.

## 2. O que de fato falta

**Dados — o obstáculo real do projeto inteiro.** Federal (IBAMA + ICMBio) está resolvido ou quase. Estadual e municipal não — e isso não é mais suposição: o levantamento da Seção 3 (27 UFs, busca dirigida) confirma o padrão esperado, com uma reviravolta. Nenhuma das 9 UFs da Amazônia Legal — o recorte geográfico atual do EGMS — tem indício forte de dado aberto estruturado de autuação; a maioria oferece só consulta processual individual, não dataset. As duas exceções fortes do levantamento inteiro (Paraná e Ceará, ambos com autuação georreferenciada e download em shapefile/KML/PDF) estão fora do escopo geográfico atual do projeto. Municipal permanece inteiramente fora do levantamento — nem os estados mais avançados descem a esse nível de granularidade. Cada órgão que entrar, além disso, traz sua própria tipologia de infração (o de-para de 6 códigos do IBAMA vira um de-para por órgão), e cobertura desigual — "sem autuação" precisa virar explicitamente "sem dado disponível" quando um órgão simplesmente não é digitalizado, replicando em escala maior a mesma ressalva que já existe hoje para o nível estadual como bloco único.

**Metodologia.** O `gap_type` binário (federal presente/ausente) não escala para múltiplas jurisdições simultâneas — "federal ausente, estadual presente" é substantivamente diferente de "ausente em todas as esferas", e hoje colapsaria nas duas mesma categoria. A pesquisa de verificação de 2026-07-20 tornou isso concreto: SEMAS-PA e IPAAM atuam exatamente nos estados que concentram 18/20 do topo do ranking atual, invisíveis ao dado federal. A normalização por área municipal foi resolvida no MVP (Fix S12, coluna `pct_desmatado` via IBGE Áreas Territoriais); a versão nacional pede o passo seguinte — normalizar por floresta *remanescente*, não por território total, o que exige camada de cobertura vegetal por bioma. Limiares de materialidade calibrados para a unidade mínima de mapeamento do PRODES Amazônia não necessariamente valem para PRODES Cerrado ou para MapBiomas, se este entrar como fonte complementar. E o join espacial em si precisa de uma camada de polígonos de bioma oficiais e de uma estratégia definida para quando um registro de enforcement não vier com coordenada — geocodificar por endereço, ou cair para o centroide do município com uma flag explícita de precisão reduzida.

**Engenharia.** Passar de 4 downloads manuais para dezenas de fontes automatizadas pede uma camada de orquestração (algo como dbt para a parte SQL, um agendador tipo Airflow/Dagster para ingestão e monitoramento de quebras por fonte) — o pipeline atual, feito para rodar manualmente uma vez por sessão de trabalho, não foi desenhado para isso. Uma decisão de produto que muda tudo a jusante: painel retrospectivo anual (como hoje) ou monitoramento quase em tempo real (ao estilo DETER)? E se o projeto passar a ter mais de uma pessoa mantendo pipelines simultaneamente, vale revisitar a trava de escritor único do DuckDB (discutimos isso antes) — não necessariamente trocar de motor, mas não é mais uma decisão trivial.

**Institucional e legal.** Bases estaduais e municipais provavelmente exigem pedido via Lei de Acesso à Informação, órgão por órgão — isso é trabalho de pesquisa, não de engenharia, e não tem atalho técnico. E um produto que nomeia e ranqueia órgãos específicos por omissão de fiscalização introduz um incentivo adversarial que o MVP atual não tem (IBAMA e ICMBio não são "avaliados" pelo sistema hoje, só citados como fonte) — isso pede um processo formal de contestação e correção, além da postura de "hipótese, não veredito" que já existe.

**Produto e equipe.** Um projeto solo não cobre GIS/geoprocessamento de verdade (projeções, topologia de polígono), nem o conhecimento jurídico necessário para reconciliar tipologias de infração entre esferas federal/estadual/municipal, nem a capacidade de sustentar dezenas de pedidos de acesso à informação em paralelo. E existe uma decisão de público em aberto — dashboard de pesquisa interno versus produto público de *accountability* — que muda o nível de rigor de comunicação de incerteza exigido em cada peça.

## 3. Mapeamento de dados abertos estaduais — levantamento por UF

Para cada uma das 27 unidades federativas, o órgão ambiental estadual responsável por autuações, e se há algum indício de dado aberto (portal dedicado, download em massa, geoespacializado) versus só consulta individual de processo.

**Metodologia e limite honesto:** levantamento feito via busca na web, um órgão por vez — **não** é uma verificação de acesso direto a cada portal (a maioria dos portais de transparência é provavelmente renderizada em JavaScript, que uma busca de texto não atravessa). A classificação por nível de confiança reflete o que apareceu nos resultados de busca, não um teste real de download. Antes de qualquer decisão de arquitetura, os itens de Nível 1 e 2 precisam de verificação direta (abrir o portal, tentar baixar um dataset real).

**Níveis de confiança:** **N1** — dado aberto com indício forte de download em massa/geoespacializado (portal tipo CKAN, shapefile/KML/PDF de autuações, ou dataset explicitamente listado). **N2** — portal de transparência com página dedicada a autos de infração, mas sem confirmação de bulk download (pode ser só consulta individual por número de processo). **N3** — só notícia de operação/consulta processual individual, nenhum indício de dataset aberto.

### Amazônia Legal (as 9 UFs mais relevantes para o EGMS hoje)

| UF | Órgão | Nível | O que foi encontrado |
|---|---|---|---|
| PA | SEMAS | N2 | Portal da Transparência Ambiental + Portal de Serviços e Sistemas — consulta de denúncias/multas/embargos; não confirmado bulk download. Atualização 2026-07-20: portal "Regulariza Pará" (análise de CAR, desde mar/2021) publica dados de geoprocessamento para download; Operação Curupira divulga números operacionais agregados (196 autos, R$87,9M, 30.592 ha embargados acumulados) — melhor candidato da Amazônia Legal a pedido LAI |
| MT | SEMA-MT | N1* | Portal de dados abertos real (`dadosabertos.mt.gov.br`, CKAN) com 5 datasets da SEMA-MT — mas nenhum é especificamente autuação/multa (são desmatamento, áreas contaminadas, exploração florestal, compensação ambiental). Autuação em si está no sistema "Siga" (consulta processual, não bulk) |
| AM | IPAAM | N3 | Só notícias de operações; nenhum portal de dados abertos localizado. Atualização 2026-07-20: relatórios operacionais detalhados existem (Tamoiotatá 2025: R$144,7M em multas, 164 embargos, 16.176 ha, por município) e há Relatório Anual de Desmatamento — dado agregado publicado, dataset de autuação não |
| AC | SEMA-AC | N3 | Só notícias de operações; nenhum portal localizado |
| MA | SEMA-MA | N2 | `transparencia.sema.ma.gov.br/page/autos_infracao` — página dedicada a autos de infração; fetch retornou vazio (provável renderização JS), download não confirmado |
| RO | SEDAM | N2 | Portal de Transparência (`transparencia.sedam.ro.gov.br`) + Geoportal com dados geoespaciais; autuação especificamente não confirmada |
| RR | FEMARH | N2 | Portal "ÚNICO" (`transparencia.femarh.rr.gov.br`) menciona dados de multas; bulk não confirmado |
| TO | Naturatins | N3 | Sistema SIGA de consulta processual individual (multas, embargos, notificações); sem indício de dataset aberto |
| AP | SEMA-AP | N3 | Página de serviço "Auto de Infração Ambiental"; nenhum portal de dados abertos localizado |

*MT tem a infraestrutura de dados abertos mais madura do grupo (portal CKAN de verdade), mas — pelo que a busca mostrou — ainda não expõe autuação/multa nele.

### Sudeste

| UF | Órgão | Nível | O que foi encontrado |
|---|---|---|---|
| SP | CETESB | N2 | Página "Autuações Aplicadas" organizada por ano/mês (2013–2025) + sistema digital "e.ambiente"; parece o caso mais estruturado do país em atualidade e granularidade temporal, mas não confirmei bulk download vs. só navegação por página |
| RJ | INEA | N3 | Nenhum portal de dados abertos localizado; só menção a processos individuais e ao programa de conversão de multas |
| MG | FEAM/SEMAD | N2 | `transparencia.meioambiente.mg.gov.br` tem página "Informações Autos de Infração" dedicada; bulk não confirmado |
| ES | IEMA | N3 | Menção a um "Plano de Dados Abertos" institucional, mas nenhum dataset específico de autuação localizado |

### Sul

| UF | Órgão | Nível | O que foi encontrado |
|---|---|---|---|
| RS | FEPAM | N2 | Página "Infrações ambientais" + seção "Dados Transparência" com autuações pagas/em aberto por trimestre — granularidade agregada, não claramente registro a registro |
| SC | IMA | N1* | Presença confirmada no portal de dados abertos catarinense (`dados.sc.gov.br/organization/about/ima`); conteúdo específico de autuação não confirmado no que a busca retornou |
| PR | IAT | N1 | Funcionalidade explícita de visualizar geograficamente áreas autuadas/embargadas, consultar metadados **e baixar dados** — sinal mais forte de dado aberto geoespacial de autuação entre todas as 27 UFs |

### Centro-Oeste

| UF | Órgão | Nível | O que foi encontrado |
|---|---|---|---|
| MS | IMASUL | N3 | Sistema SIRIEMA (processual) + boletins/relatórios; sem indício de dataset aberto |
| GO | SEMAD | N2 | Página dedicada "Dados Abertos" no site institucional; conteúdo específico de autuação não confirmado |
| DF | IBRAM | N1* | Presença confirmada no portal de dados abertos do GDF (`dados.df.gov.br`); dado histórico de arrecadação de multas mencionado desde 2008; dataset específico de autuação não confirmado no que a busca retornou |

### Nordeste (exceto MA, já listado na Amazônia Legal)

| UF | Órgão | Nível | O que foi encontrado |
|---|---|---|---|
| BA | INEMA | N3 | Só consulta processual (licenciamento/fiscalização); nenhum portal de dados abertos localizado |
| SE | ADEMA | N3 | Menção genérica a "dados abertos" na missão institucional; nenhum portal concreto localizado |
| AL | IMA-AL | N3 | Portal de licenciamento (`licenciamento.ima.al.gov.br`) + app de denúncia; sem dados abertos |
| PE | CPRH | N2 | "Dados estatísticos abertos para download" mencionados via Plataforma Ecológico-Econômica de Pernambuco — sinal razoável, não verificado diretamente |
| PB | SUDEMA | N3 | Só notícias de operações; nenhum portal localizado |
| RN | IDEMA | N3 | Sistema SEIA (informação ambiental geral) e SISLIA (licenciamento); autuação aberta não confirmada |
| CE | SEMACE | N1 | **O achado mais forte de todo o levantamento.** 10.719 autos de infração emitidos 2012–2024, dos quais 10.436 (97%) georreferenciados em UTM; mapas em PDF, KML e shapefile disponíveis para download, resultado de um projeto de estruturação de SIG (DIFIS) |
| PI | SEMARH/SEMAR | N2 | Página dedicada "Autos de Infrações"; bulk não confirmado |

### Síntese do mapeamento

De 27 UFs, **2 (PR e CE)** têm indício forte e específico de dado aberto geoespacializado de autuação, pronto ou quase pronto para uso — coincidentemente, nenhuma das duas é Amazônia Legal, o que significa que o recorte geográfico original do EGMS não é onde a melhor infraestrutura de dado estadual está. **MT, SC e DF** têm portais de dados abertos institucionais reais, mas sem o dataset de autuação especificamente publicado neles ainda — candidatos a pedido de dados (LAI) com boa chance de resposta, já que a cultura de publicação já existe. As **9 UFs da Amazônia Legal**, o recorte geográfico atual do projeto, têm em geral a infraestrutura mais fraca do levantamento (a maioria em N2 ou N3) — reforça o Fix "enforcement estadual não capturado" do MVP atual: não é só que o EGMS não usa esse dado, é que a maior parte dele provavelmente não existe em formato utilizável sem pedido formal.

## 4. Sequenciamento sugerido, dado o que já está pronto

1. **Completar o federal primeiro:** IBAMA (já no pipeline) + ICMBio (dado aberto geoespacializado, pronto, atualizado mensalmente desde 2023) — menor esforço, maior retorno, e resolve uma fatia real da limitação de "enforcement não federal não capturado" sem sair da esfera federal.
2. **Multi-bioma via PRODES Brasil** — a fonte já existe desde 2022; é troca de filtro na ingestão, não mudança de arquitetura.
3. **Migrar geocode → join espacial dentro do próprio DuckDB**, usando a extensão spatial, como prova de conceito de baixo risco antes de qualquer decisão sobre trocar de motor.
4. **Verificar de fato os 5 casos N1 da Seção 3**, começando por Paraná e Ceará — que, apesar de fora da Amazônia Legal, são a prova de conceito mais barata disponível para o join espacial e a ingestão multi-fonte, exatamente porque já publicam o dado pronto e geoespacializado. Testar o pipeline completo (ingestão → join espacial → classificação) nesses dois estados antes de investir em qualquer estado da Amazônia Legal.
5. **Só depois, o item caro de verdade:** aquisição de dados nas 9 UFs da Amazônia Legal e no nível municipal, majoritariamente via Lei de Acesso à Informação, órgão por órgão — sem atalho técnico. Trate como sua própria fase de pesquisa, com entregável próprio, não como uma linha a mais no pipeline.

---

**Fontes consultadas nesta sessão:**
- [PRODES – BIG – BiomasBR](https://data.inpe.br/biomasbr/prodes-monitoramento-anual-da-supressao-de-vegetacao-nativa/) — expansão do PRODES para Cerrado (2018) e demais biomas (2022)
- [Spatial Joins in DuckDB – DuckDB](https://duckdb.org/2025/08/08/spatial-joins) / [PostGEESE? Introducing The DuckDB Spatial Extension](https://duckdb.org/2023/04/28/spatial) — extensão espacial e operador de spatial join
- [Fiscalização - auto de infração - coordenadas geográficas - IBAMA](https://dadosabertos.ibama.gov.br/dados/SIFISC/auto_infracao/coordenada/coordenada.html) — campos de latitude/longitude/WKT já presentes no dataset bruto do IBAMA
- [ICMBio disponibiliza nome e CPF de infratores ambientais — Agência Gov](https://agenciagov.ebc.com.br/noticias/202308/icmbio-disponibiliza-nome-e-cpf-de-infratores) — abertura de dados do ICMBio (2023) e base histórica 2009–2021
- [Portal de Dados Abertos - Mato Grosso (SEMA-MT)](https://dadosabertos.mt.gov.br/organization/sema-mt) — 5 datasets, nenhum de autuação
- [Autos de Infração | Instituto Água e Terra (PR)](https://www.iat.pr.gov.br/Pagina/Autos-de-Infracao) — visualização geográfica e download de áreas autuadas/embargadas
- [Fiscalização ambiental — SEMACE (CE)](https://www.semace.ce.gov.br/fiscalizacao-ambiental/autos-de-infracao-e-outras-sancoes/) — 10.719 autos 2012–2024, 97% georreferenciados, download em PDF/KML/shapefile
- [SEMA - Transparência (MA)](https://transparencia.sema.ma.gov.br/page/autos_infracao) / [Dados Transparência - FEPAM (RS)](https://fepam.rs.gov.br/dados-transparencia) / [Autuações Aplicadas - CETESB (SP)](https://cetesb.sp.gov.br/documentos-emitidos/autuacoes/) / [Informações Autos de Infração - transparência MG](https://transparencia.meioambiente.mg.gov.br/views/introducao_autos_infracao.php) / [Dados Abertos - Semad (GO)](https://goias.gov.br/meioambiente/dados-abertos/) — portais de transparência estaduais com página dedicada a autos de infração, Nível 2
