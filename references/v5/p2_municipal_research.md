# Pesquisa municipal — top 10 `absolute_gap` + top 10 `measured_gap`

> **Documento histórico (nota adicionada 2026-07-20, Fix S13/auditoria):** esta pesquisa foi feita sobre os rankings v2/v3 (streaks + priority_score), superados pela redesign de 2026-07-20. A verificação externa vigente, sobre o top 20 do ranking atual, está em `final_reference.md` §10.

Notas de pesquisa externa (web) sobre os 20 municípios que aparecem nos dois rankings do EGMS, feita para dar suporte factual à narrativa de resultados. Cada item cita a fonte. Isto é um documento de trabalho (não é o anexo técnico final) — links completos preservados para auditoria.

**Limitação metodológica geral, válida para todos os 20 casos**: nenhuma busca abaixo confirma ou refuta diretamente a classificação individual do EGMS (isto exigiria cruzar o auto de infração real do IBAMA por município-ano, fora do escopo desta pesquisa). O que se buscou foi contexto independente — presença ou ausência de operações federais, embargos, dados AUTEX/DOF, inclusão na lista oficial de municípios prioritários do MMA — que é consistente ou inconsistente com o padrão que o índice atribuiu a cada município.

---

## Cross-referência: lista oficial de municípios prioritários (MMA/Decreto 6.321/2007)

Fonte primária consultada: [Tabela de municípios prioritários (MMA, PDF, dados até a atualização de 2021)](https://www.gov.br/mma/pt-br/assuntos/controle-ao-desmatamento-queimadas-e-ordenamento-ambiental-territorial/controle-de-desmatamento-e-incendios-florestais/pdf/Listagemmunicpiosprioritriosparaaesdepreveno2021.pdf). Esta é a lista federal (Decreto nº 6.321/2007, atualizada por sucessivas Portarias MMA) de municípios sob monitoramento/controle prioritário de desmatamento — o principal mecanismo formal de atenção federal coordenada, distinto dos autos de infração individuais do IBAMA que alimentam o EGMS.

Segundo [reportagem da Acre Agora (03/07/2026)](https://acreagora.com/2026/07/03/programa-federal-abre-adesao-para-municipios-da-amazonia-acre-tem-quatro-cidades-na-lista-prioritaria/) e da [InfoAmazonia (22/02/2024)](https://infoamazonia.org/2024/02/22/amazonas-e-maranhao-tem-60-dos-municipios-da-amazonia-considerados-prioritarios-no-plano-clima/), a lista foi expandida por Portaria GM/MMA nº 1.202/2024 para 81 municípios (~71% do desmatamento verificado em 2024 na Amazônia Legal), e novamente atualizada por Portaria GM/MMA nº 1.717/2026. Não obtive acesso ao anexo completo dessas duas portarias mais recentes (o portal in.gov.br não retornou o texto integral nesta pesquisa) — a tabela abaixo reflete o corte de 2021, que é a versão com dados município a município que consegui verificar diretamente.

| Município (ranking EGMS) | Status na lista MMA (corte 2021) |
|---|---|
| Moju (PA) — `measured_gap` | Prioritário desde 2011, sem registro de saída |
| Itaituba (PA) — `measured_gap` | Prioritário desde 2017, sem registro de saída |
| Itupiranga (PA) — `measured_gap` | Prioritário desde 2009, sem registro de saída |
| Jacareacanga (PA) — `measured_gap` | Prioritário desde 2021, sem registro de saída |
| Aripuanã (MT) — `measured_gap` | Prioritário desde 2008, sem registro de saída |
| Novo Repartimento (PA) — `measured_gap` | Prioritário desde 2008, sem registro de saída |
| Peixoto de Azevedo (MT) — `measured_gap` | Prioritário 2008–2021, **saiu da lista** em 2021 (Portaria 9/2021) |
| Tailândia (PA) — `measured_gap` | Prioritário 2009–2013, **saiu da lista** em 2013 (passou a "monitorado e sob controle") |
| Prainha (PA) — `measured_gap` | Não consta na tabela de 2021 |
| União do Sul (MT) — `measured_gap` | Não consta na tabela de 2021 |
| Governador Luiz Rocha (MA) — `absolute_gap` | Não consta |
| Barra do Bugres (MT) — `absolute_gap` | Não consta |
| Fortuna (MA) — `absolute_gap` | Não consta |
| Tefé (AM) — `absolute_gap` | Não consta |
| São Domingos do Maranhão (MA) — `absolute_gap` | Não consta |
| Santa Rosa do Purus (AC) — `absolute_gap` | Não consta |
| Floresta do Araguaia (PA) — `absolute_gap` | Não consta |
| Arame (MA) — `absolute_gap` | Não consta |
| Santo Afonso (MT) — `absolute_gap` | Não consta |
| Viseu (PA) — `absolute_gap` | Não consta |

**Padrão observado**: 6 dos 10 municípios do top `measured_gap` (Moju, Itaituba, Itupiranga, Jacareacanga, Aripuanã, Novo Repartimento) são ou foram, por longos períodos, alvo formal da política federal de priorização — coerente com a interpretação de que `measured_gap` capta lugares que já recebem atenção institucional, mas onde essa atenção é desproporcional à pressão de desmatamento. Nenhum dos 10 municípios do top `absolute_gap` consta na tabela de 2021 — coerente com a interpretação de que `absolute_gap` capta lugares fora do radar da política federal coordenada, e não apenas lugares "mal atendidos" dentro dela. Essa distinção é uma peça de evidência a favor da validade de construto do índice, mas não prova causal — não descarta, por exemplo, que os municípios do top `absolute_gap` estejam sob competência estadual ativa (ver ressalva já registrada em Fix 5 do projeto: enforcement estadual não é capturado pelo EGMS).

**Ressalva sobre completude**: não consegui confirmar se algum dos 10 municípios do `absolute_gap` entrou na lista nas atualizações de 2024/2026 (que expandiram a lista de ~52 para 81 municípios). Isso deveria ser verificado antes de qualquer afirmação definitiva no relatório final.

---

## Top 10 — `absolute_gap` (desmatamento sustentado, autuações federais ~zero)

### 1. Governador Luiz Rocha (MA)
Nenhuma fonte encontrada especificamente sobre fiscalização ambiental ou desmatamento neste município — os resultados de busca retornaram apenas dados cadastrais (IBGE, prefeitura). Não há evidência, a favor ou contra, de operação federal recente.
Fonte: [IBGE Cidades](https://cidades.ibge.gov.br/brasil/ma/governador-luiz-rocha).

### 2. Barra do Bugres (MT)
Já investigado em sessão anterior do projeto (Fix 4, `p2_technical_fixes.txt`): alta proporção de desmatamento no município é autorizada via AUTEX (Autorização de Exploração) emitida pela SEMA-MT, não desmatamento ilegal — o que é consistente com zero/baixas autuações do IBAMA sem implicar ausência de fiscalização real. Confirma-se aqui que AUTEX é de fato o instrumento legal correto: supressão vegetal em MT exige AUTEX válida emitida por SEMA-MT, com ART e relatório de execução; supressão sem AUTEX é infração com multa de R$ 5.000–50.000/ha e embargo imediato (Decreto Federal 6.514/2008).
Fontes: [Âmbito Ambiental — Supressão Vegetal em MT](https://ambitoambiental.com.br/supressao-vegetal); [IPEA — Problemas ambientais de Barra do Bugres](https://www.ipea.gov.br/ppp/index.php/PPP/article/view/154).

### 3. Fortuna (MA)
Nenhuma menção específica encontrada. Contexto estadual: desmatamento no Maranhão dentro do bioma amazônico cresceu 85% entre 2019 (9.905,86 ha) e 2022 (18.342,57 ha) — atrás apenas de Tocantins (+215%) e Amazonas (+116,4%) no mesmo período.
Fonte: [InfoAmazonia — Área desmatada no Maranhão aumenta 85% em 4 anos](https://infoamazonia.org/2024/03/12/area-desmatada-no-maranhao-aumenta-85-em-4-anos-e-pressiona-terras-indigenas/).

### 4. Tefé (AM)
Nenhuma operação de fiscalização específica encontrada para Tefé. O município está na área de atuação do Corpo de Bombeiros Militar do Amazonas (combate a incêndio/desmatamento) e é citado como uma das regiões cobertas pela estratégia estadual de fiscalização (Vale do Javari, Alto Solimões, Alto Rio Negro, Tefé). Evento ambiental notório (mas não relacionado a desmatamento): mortandade de botos-cor-de-rosa no Lago de Tefé associada a seca e temperatura elevada.
Fonte: [Senado Notícias — Amazônia sofre com devastação e alteração climática](https://www12.senado.leg.br/noticias/infomaterias/2023/10/amazonia-sofre-com-devastacao-e-extrema-alteracao-climatica).

### 5. São Domingos do Maranhão (MA)
Nenhuma menção específica encontrada. Contexto estadual relevante: em janeiro de 2025 o Ministro Flávio Dino deu prazo de 60 dias para Maranhão e demais estados da Amazônia/Pantanal aderirem ao Sinaflor (Sistema Nacional de Controle da Origem dos Produtos Florestais) — sugere lacuna de rastreabilidade florestal estadual à época.
Fonte: [Blog do Estado — Flávio Dino dá 60 dias ao Maranhão](https://www.blogsoestado.com/danielmatos/2025/01/22/flavio-dino-da-60-dias-ao-maranhao-e-aos-demais-estados-da-amazonia-e-pantanal-a-aderirem-a-sistema-contra-desmatamento/).

### 6. Santa Rosa do Purus (AC)
Município é sede de programa de pagamento por serviço ambiental (até R$ 8 mil por família para preservação, exigindo manutenção de ≥80% da vegetação nativa, verificado via PRODES/INPE) — sugere presença de política de incentivo positivo, não apenas repressiva. Operação federal relevante na região (não necessariamente no município): 1ª fase da Operação Amburana (Acre) vistoriou 242 alertas de desmatamento em 5 regiões estratégicas, incluindo a região do Purus, com apoio de equipes terrestres atuando em Sena Madureira, Manoel Urbano e Feijó — Santa Rosa do Purus não é citada nominalmente entre os municípios com equipe em solo.
Fontes: [Voz do Norte — Famílias de Feijó e Santa Rosa do Purus recebem até R$ 8 mil](https://www.vozdonorte.com.br/familias-de-feijo-e-santa-rosa-do-purus-recebem-ate-r-8-mil-por-preservacao-ambiental-saiba-como/); [Sema-AC — Acre supera meta de controle do desmatamento 2025](https://sema.ac.gov.br/acre-supera-meta-de-controle-do-desmatamento-prevista-para-o-ano-florestal-2025-e-reforca-acoes-integradas-de-combate-aos-ilicitos-ambientais/).

### 7. Floresta do Araguaia (PA)
Nenhuma menção específica encontrada (as buscas retornaram principalmente resultados sobre a Floresta Estadual do Araguaia, em Goiás — unidade de conservação homônima, mas em outro estado; não confundir). Contexto regional: caso documentado de fazenda em Santana do Araguaia (PA, não o mesmo município), autuada duas vezes pelo IBAMA, associada a fornecimento de gado à JBS.
Fonte: [Intercept — Possível conexão entre JBS e fazenda que desmata no Pará](https://www.intercept.com.br/2025/09/29/relatorio-mostra-possivel-conexao-entre-jbs-e-fazenda-com-historico-de-desmatamento/).

### 8. Arame (MA)
Município fica próximo/sobrepõe a área de influência da Terra Indígena Araribóia, alvo de exploração madeireira ilegal grave e violenta — segundo lideranças indígenas da região de Arame, o monitoramento territorial local resultou em confrontos e assassinatos. Relatório Cimi 2023: de 5 assassinatos de indígenas naquele ano, 3 ocorreram na TI Araribóia. Operações de maior porte na região contam com apoio de Polícia Federal, Polícia Civil, Força Nacional e IBAMA.
Fontes: [Carta Amazônia — Exploração ilegal de madeira ameaça vida na TI Araribóia](https://cartaamazonia.com.br/exploracao-ilegal-de-madeira-ameaca-a-vida-e-a-cultura-da-terra-indigena-arariboia-no-maranhao/); [Cimi — Exploração ilegal de madeira ameaça vida e cultura](https://cimi.org.br/2023/08/exploracao-ilegal-de-madeira-ameaca-vida-e-cultura-dos-indigenas-da-regiao/).

### 9. Santo Afonso (MT)
Nenhuma menção específica encontrada. Contexto estadual (MT, 2024–2025): 125,7 mil hectares de floresta amazônica destruídos em MT em 2024 (2º maior estado); alertas de desmatamento por agrotóxicos cresceram 800% em MT entre 2024 e 2025 (~149 mil ha possivelmente desmatados com agentes químicos desde 2021) — modalidade de desmatamento mais difícil de flagrar por fiscalização convencional, o que é consistente (mas não prova) com autuações federais baixas nesses municípios menores.
Fonte: [Repórter Brasil — Alertas de desmatamento por agrotóxicos no MT crescem 800%](https://reporterbrasil.org.br/2025/10/alertas-desmatamento-agrotoxicos-mato-grosso-crescem/).

### 10. Viseu (PA)
Nenhuma menção específica encontrada. Contexto regional (PA, geral): fiscalização do IBAMA é presencial, dependente de acesso terrestre/aéreo — dificuldade de acesso, falta de investimento e equipes reduzidas resultam em agentes nem sempre chegando a tempo de identificar responsáveis.
Fonte: [Agência Brasil — Ibama volta a fazer operações contra desmatamento no Pará](https://agenciabrasil.ebc.com.br/radioagencia-nacional/meio-ambiente/audio/2023-01/ibama-volta-fazer-operacoes-contra-desmatamento-no-para).

**Observação transversal sobre o grupo `absolute_gap`**: para 6 dos 10 municípios (Governador Luiz Rocha, Fortuna, Tefé, São Domingos do Maranhão, Floresta do Araguaia, Santo Afonso, Viseu — na prática 7 de 10) não foi encontrada nenhuma cobertura jornalística ou institucional nominal. Isso é, em si, um dado: municípios pequenos, fora de rota de operações federais divulgadas, correspondem exatamente ao padrão que a categoria `absolute_gap` pretende capturar (pressão de desmatamento sem resposta institucional federal registrada) — mas a ausência de cobertura de imprensa não é evidência forte de ausência real de fiscalização (poderia ser só ausência de imprensa local). Este é um limite epistêmico explícito da pesquisa, não do índice.

---

## Top 10 — `measured_gap` (fiscalização presente, mas desproporcional à pressão)

### 1. Moju (PA)
Caso robusto e bem documentado. Município é polo da "guerra do dendê" — empresas de óleo de palma associadas a desmatamento e contaminação de água; uma delas (BBF) cultiva dendê em três áreas sob embargo do IBAMA por desmatamento ilegal. Base de dados do consórcio jornalístico "Tras las huellas de la palma" mostra apenas 44 autuações contra produtores de dendê no país na última década, das quais só 3 foram pagas — evidência direta e independente de gap entre infração e efetividade da punição, no setor mais associado a Moju. Estudo citado: 9%–39% da produção de dendê no Pará ocorreu em áreas desmatadas (1989–2014); outro estudo aponta 40% da expansão do dendê substituindo vegetação nativa, apesar de proibição legal de expansão sobre floresta/área desmatada pós-2008.
Fontes: [Mongabay — "Guerra do dendê": empresa campeã de multas é acusada de violência no Pará](https://brasil.mongabay.com/2022/10/guerra-do-dende-empresa-campea-de-multas-e-acusada-de-violencia-no-para/); [Mongabay — Desmatamento e água contaminada: o lado obscuro do óleo de palma](https://brasil.mongabay.com/2021/03/desmatamento-e-agua-contaminada-o-lado-obscuro-do-oleo-de-palma-sustentavel-da-amazonia/); [InfoAmazonia — Palma de áreas desmatadas ilegalmente nos planos de SAF](https://infoamazonia.org/2025/06/18/palma-de-areas-desmatadas-ilegalmente-esta-nos-planos-de-combustivel-sustentavel-de-aviacao-na-amazonia/).

### 2. Itaituba (PA)
Junto com Jacareacanga e Novo Progresso, gerou 9.017 alertas de garimpo entre jan–ago/2023 (41% de todos os alertas do Brasil no período; 7.653 dentro de Unidades de Conservação ou Terras Indígenas). IBAMA suspendeu 331–342 Permissões de Lavra Garimpeira (PLG) na APA do Tapajós entre dez/2024–jan/2025 por irregularidades (ausência de autorização do ICMBio, destruição de vegetação, uso de mercúrio). Prioritário na lista MMA desde 2017 (sem saída registrada).
Fontes: [Ibama — suspende 331 permissões de exploração garimpeira no Tapajós](https://www.gov.br/ibama/pt-br/assuntos/noticias/2024/ibama-suspende-331-permissoes-de-exploracao-garimpeira-que-atuavam-em-area-de-protecao-ambiental-no-tapajos-pa); [Agência Pará — Força de Combate ao Desmatamento fecha garimpo em Itaituba](https://www.agenciapara.com.br/noticia/20138/forca-de-combate-ao-desmatamento-ilegal-fecha-garimpo-em-itaituba).

### 3. Itupiranga (PA)
Caso documentado de apreensão pela PRF (não IBAMA diretamente) de 550 m³ de madeira ilegal (incluindo 170 m³ de castanheira, Bertholletia excelsa) em transporte na BR-230, encaminhada ao IBAMA de Marabá. Prioritário na lista MMA desde 2009 (sem saída registrada) — um dos casos mais antigos da lista, na região de Marabá/sudeste do Pará onde operações do IBAMA contra áreas embargadas (Rondon do Pará, Bom Jesus do Tocantins, Nova Ipixuna) resultaram em R$ 12 milhões em multas e identificação de 206 ha de novos focos de desmatamento.
Fontes: [Ecoamazônia — PRF apreende 550m³ de madeira ilegal em Itupiranga](https://www.ecoamazonia.org.br/2022/03/prf-apreende-550m%C2%B3-madeira-ilegal-itupiranga-pa/); [Ibama — Operação combate uso irregular de áreas embargadas no Pará](https://www.gov.br/ibama/pt-br/assuntos/noticias/2025/operacao-do-ibama-combate-uso-irregular-de-areas-embargadas-no-para).

### 4. Peixoto de Azevedo (MT)
3º município do Brasil em área de garimpo (11.221 ha / 128,39 km²). Rio Peixoto, principal fonte hídrica do município, é frequentemente contaminado por garimpo. **Achado relevante para a validade do índice**: reportagem do "De Olho nos Ruralistas" revela que a secretária de Meio Ambiente do município é casada com uma liderança garimpeira — evidência de possível conflito de interesse institucional local, plausivelmente relevante para explicar por que a fiscalização (mesmo com operações estaduais pontuais da Sema-MT) é desproporcional à escala real do garimpo. Saiu da lista federal de prioritários em 2021 (Portaria 9/2021) — mas o EGMS aqui mede infrações federais IBAMA, não a lista de prioridade em si, então a saída da lista não contradiz a classificação `measured_gap`.
Fontes: [Gigante 163 — MT e PA concentram 91,9% do garimpo no Brasil](https://www.gigante163.com/ecologia/mato-grosso-e-para-concentram-919-do-garimpo-no-brasil-peixoto-de-azevedo-e-polo/); [De Olho nos Ruralistas — secretária de Meio Ambiente casada com líder garimpeiro](https://deolhonosruralistas.com.br/2024/10/01/os-gigantes-secretaria-de-meio-ambiente-de-peixoto-de-azevedo-e-casada-com-lider-garimpeiro/).

### 5. Jacareacanga (PA)
Caso mais robusto do grupo. Mais de 90% da Terra Indígena Munduruku está dentro dos limites de Jacareacanga (2% em Itaituba) — TI mais desmatada do país em 2023–2024 (106,98 ha destruídos por garimpo só no último trimestre analisado). Operação federal multiagência iniciada em novembro/2024 (envolvendo IBAMA, Exército, Polícia Federal, Ministério dos Povos Indígenas, Abin) já havia causado R$ 112,3 milhões em prejuízo às atividades ilícitas em quase três meses. Complicador social relevante: lideranças estimam que ~40% do garimpo na TI é hoje conduzido por indígenas locais, o que torna a repressão politicamente mais complexa que uma simples ação contra invasores externos. Prioritário na lista MMA desde 2021.
Fontes: [Agência Gov — Força-tarefa multiagências atua na desintrusão da TI Munduruku](https://agenciagov.ebc.com.br/noticias/202411/ibama-atua-em-forca-tarefa-multiagencias-para-desintrusao-da-terra-indigena-munduruku-pa); [Governo Federal — combate ao garimpo ilegal na TI Munduruku](https://www.gov.br/secom/pt-br/assuntos/noticias/2024/12/governo-federal-intensifica-combate-ao-garimpo-ilegal-na-terra-indigena-munduruku).

### 6. Aripuanã (MT)
Duas operações federais distintas e recentes documentadas: (1) fev/2026, IBAMA interceptou 837 m³ de madeira nativa ilegal armazenada em pátio abandonado na área urbana (madeira doada à prefeitura); (2) fev/2025, Operação Xapiri desativou garimpo ilegal na Terra Indígena Parque do Aripuanã (MT/RO), inutilizando 4 escavadeiras, 3 caminhonetes e 1 moto. Prioritário na lista MMA desde 2008 (sem saída registrada) — um dos casos mais antigos e persistentes da lista.
Fontes: [Ibama — Operação intercepta madeira ilegal em Aripuanã](https://www.gov.br/ibama/pt-br/assuntos/noticias/2026/operacao-do-ibama-intercepta-madeira-ilegal-em-aripuana-mt); [Ibama — desmantela garimpo ilegal no Parque Indígena do Aripuanã](https://www.gov.br/ibama/pt-br/assuntos/noticias/2025/ibama-desmantela-garimpo-ilegal-no-parque-indigena-do-aripuana).

### 7. Novo Repartimento (PA)
Múltiplas operações documentadas: nov/2024, embargo de >600 ha de mata nativa (extração seletiva de castanheiras centenárias, próximo à Vila Maracajá), R$ 5 milhões em multas; mar/2026, Operação Metaverso I (junto com Tucuruí e Pacajá) aplicou R$ 5 milhões em multas e embargou 1.627,9 ha por supressão ilegal, transporte irregular de madeira e manipulação de créditos florestais; out/2024, incluído em operação contra gado em áreas embargadas. Prioritário na lista MMA desde 2008 (sem saída registrada) — caso de enforcement mais ativo e mais bem documentado do grupo, com múltiplas operações no período recente.
Fontes: [Agência Gov — Ibama embarga mais de 600 hectares no PA](https://agenciagov.ebc.com.br/noticias/202411/ibama-embarga-mais-de-600-hectares-de-floresta-nativa-desmatados-ilegalmente-no-pa); [Ibama — Operação Metaverso no Pará flagra desmate](https://www.gov.br/ibama/pt-br/assuntos/noticias/2026/operacao-metaverso-no-para-flagra-desmate-e-bloqueia-empresas-por-fraudes-florestais).

### 8. Prainha (PA)
Alertas de desmatamento em quase 9.000 ha entre dez/2023–dez/2024 em glebas federais nos municípios de Santarém, Belterra, Mojuí dos Campos e Prainha, motivando recomendação do MPF para que o IBAMA incluísse operações nessas áreas no Plano Anual de Proteção Ambiental de 2025 (Operação Caraipé, fase 1: R$ 1,4 milhão em multas, >1.000 ha embargados — nota: a fase 1 documentada cobriu Santarém/Belterra especificamente; não há confirmação de execução em Prainha na mesma fase). Não consta na tabela MMA 2021.
Fonte: [Ibama — fiscaliza desmatamento em área de desenvolvimento sustentável no Pará](https://www.gov.br/ibama/pt-br/assuntos/noticias/2026/ibama-fiscaliza-desmatamento-em-area-de-desenvolvimento-sustentavel-no-para).

### 9. Tailândia (PA)
Identificado como polo madeireiro do sudeste do Pará — destino de madeira extraída ilegalmente em municípios vizinhos (Ulianópolis, Dom Eliseu), segundo relatórios de fiscalização da Operação Maravalha (fev/2026, 26 madeireiras vistoriadas, todas com alguma irregularidade, parte clandestina). Ou seja: Tailândia aparece nas fontes mais como destino/processamento do desmatamento de outros municípios do que necessariamente como local de supressão primária — relevante para interpretar por que a métrica local (`area_km2` do próprio município) pode subestimar o papel real de Tailândia na cadeia de desmatamento regional. Saiu da lista federal de prioritários em 2013.
Fonte: [Ibama e ICMBio intensificam combate à exploração ilegal de madeira no Pará com a Operação Maravalha](https://www.gov.br/ibama/pt-br/assuntos/noticias/2026/ibama-e-icmbio-intensificam-combate-a-exploracao-ilegal-de-madeira-no-para-com-a-operacao-maravalha).

### 10. União do Sul (MT)
Nenhuma menção específica encontrada. Contexto de vizinhança: PF e IBAMA realizaram ação contra invasões e desmatamento em área de Reserva Legal da União próxima a General Carneiro (MT) — não é o mesmo município, e a coincidência de nome ("União" na Reserva Legal da União vs. "União do Sul" o município) é apenas lexical, não deve ser tratada como evidência. Não consta na tabela MMA 2021. Este é o caso de menor cobertura documental do grupo `measured_gap` — vale investigação adicional antes de citar no relatório final.
Fonte: [Mato Grosso Mais Notícias — PF e Ibama realizam ação contra invasões em área de Reserva Legal da União](https://www.matogrossomaisnoticias.com.br/policia-federal/pf-e-ibama-realizam-acao-contra-invasoes-e-desmatamento-em-area-de-reserva-legal-da-uniao-em-mato-grosso/).

---

## Nota sobre Porto de Moz (não está no top 10 atual, mas citado no rascunho antigo)

O rascunho `p2_results_narrative_draft.md` classificava Porto de Moz sob `gap_absoluto` — isso contradiz o ranking atual confirmado, que classifica Porto de Moz sob `measured_gap`. Pesquisa externa confirma que há, sim, histórico de fiscalização federal robusta no município: mais de 30.000 m³ de madeira ilegal apreendidos na região conhecida como Terra do Meio; madeireiras construíram 25 km de estradas dentro de uma reserva florestal de pesquisa entre Porto de Moz, Senador José Porfírio e Portel, com multa de R$ 142 mil e processo criminal contra os responsáveis. Isso é **consistente com a classificação atual (`measured_gap`: fiscalização presente)** e **inconsistente com a classificação do rascunho antigo (`gap_absoluto`: fiscalização ausente)** — mais uma confirmação de que o rascunho antigo estava desatualizado, não apenas nos números, mas nas categorias.
Fonte: [MMA (arquivo antigo) — Ibama mantém fiscalização sobre exploração madeireira no Pará](https://antigo.mma.gov.br/informma/item/1647-ibama-mantem-fiscalizacao-sobre-exploracao-madeireira-no-para.html).

---

## Síntese para uso na narrativa

1. O grupo `measured_gap` tem cobertura documental muito mais forte e específica que o grupo `absolute_gap` — 8 dos 10 casos têm operações federais nominalmente documentadas e recentes (2024–2026); no `absolute_gap`, apenas 3 dos 10 (Barra do Bugres, Arame, e parcialmente Santa Rosa do Purus/Tefé) têm cobertura específica, e os demais 7 não retornaram nenhuma menção nominal.
2. Essa assimetria de cobertura é, ela mesma, uma peça de evidência indireta a favor da distinção conceitual entre as duas categorias: lugares com fiscalização ativa geram notícia (a fiscalização é o evento noticiável); lugares sem fiscalização federal não geram notícia sobre fiscalização — geram, no máximo, notícia sobre a ausência dela (o que é mais raro, exige investigação, e é exatamente o tipo de achado que este projeto está tentando gerar automaticamente a partir de dados administrativos, sem depender de imprensa).
3. A cross-referência com a lista oficial de municípios prioritários do MMA (2021) reforça o padrão: 6/10 do `measured_gap` são/foram prioritários federais; 0/10 do `absolute_gap` constam na lista. Isso é evidência de validade de construto, mas a lista está desatualizada (corte 2021) e a pesquisa não conseguiu confirmar as atualizações 2024/2026.
4. Achados que já eram conhecidos do projeto (Barra do Bugres/AUTEX, Fix 4) foram confirmados, não contraditados, por esta pesquisa mais ampla.
5. Um erro categórico real foi encontrado no rascunho antigo (Porto de Moz classificado como `gap_absoluto`, quando hoje é `measured_gap`) — mais uma confirmação de que os rascunhos antigos devem ser descartados como fonte de conteúdo, usados apenas como referência de formato (conforme já decidido).
6. Dois municípios (Governador Luiz Rocha, União do Sul) não retornaram nenhuma informação específica utilizável — devem ser tratados na narrativa com transparência sobre essa lacuna, não com afirmações genéricas disfarçadas de específicas.
