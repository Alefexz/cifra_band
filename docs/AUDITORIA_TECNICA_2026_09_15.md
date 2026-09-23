# Auditoria tecnica do Cifra Band

Data: 15/09/2026. Versao auditada: **1.5.9+27**. Aplicativo: commit `3d3eff4`; documentacao de release: `3cd0bd9`. Backend: `7daa21a`.

## 1. Parecer executivo

O aplicativo tem uma base funcional: autenticacao, isolamento de ministerios, busca agregada, cifras, setlists, biblioteca oficial, suporte e atualizacao Android. Existem testes automatizados e mecanismos de protecao relevantes. Entretanto, **ainda nao recomendo considerar o produto estabilizado para uso critico no culto sem um repertorio previamente conferido e baixado**.

Os maiores problemas encontrados nesta auditoria foram:

1. Graus e notas de acordes podem usar a forma do capotraste como se fosse o acorde real. Defeito reproduzido na tela.
2. O download da 21a setlist apaga silenciosamente a primeira. Defeito reproduzido.
3. Favoritos e anotacoes locais nao sao separados por conta. Risco de exposicao entre usuarios do mesmo aparelho.
4. Uma atualizacao obrigatoria salva localmente pode impedir a consulta de um manifesto mais novo.
5. A busca de cifra ainda pode esperar por resolucao de YouTube, embora o recurso esteja desativado na tela.
6. Ha problemas de escala e consistencia no suporte, compartilhamento de setlists e armazenamento de musicas das escalas.

**Nao houve alteracao de codigo funcional, publicacao de APK, deploy ou modificacao de registros de usuarios nesta auditoria.** Foram executados testes, leituras de infraestrutura e consultas de busca. O relatorio e os artefatos de auditoria foram gerados localmente.

## 2. Metodo e limites

- Leitura dos fluxos de Flutter, Node/Express, regras Firestore e servicos locais.
- Analise estatica completa, testes Flutter, testes de regras no emulador e testes unitarios Node.
- 50 consultas reais de descoberta musical e 8 consultas adicionais com medicao de cache.
- Cinco consultas ao endpoint publico de versao.
- Comparacao das regras publicadas no Firebase com o arquivo local; contagens agregadas, sem exportar registros pessoais.
- Tres testes de caracterizacao para reproduzir comportamentos incorretos.

Nao foi feito um pentest completo, teste de carga em producao, validacao de todas as cifras existentes, teste integral em celular/tablet, medicao de FPS/memoria/bateria, teste iOS ou simulacao de todos os provedores indisponiveis. A busca de metadados foi medida sem token Firebase: **nao mede a extracao autenticada de cifras nem a qualidade de suas letras**. Testes aprovados nao significam ausencia de bugs.

## 3. Achados prioritarios

P1: corrigir antes de confiar no fluxo em situacoes criticas. P2: corrigir no ciclo de estabilizacao. As prioridades representam impacto e risco, nao exploracao comprovada em producao.

### A01 - P1 - Capotraste mistura forma, som real e grau

**Confirmado por teste de widget.** Uma cifra em D, com forma C e capo 2, mostra `Tom Real: D`. Ao tocar no C exibido, o modal informa `Grau b7` e notas `C - E - G`. O acorde soante e D e seu grau nesse contexto e I.

Origem: o conteudo exibido usa a forma, enquanto `insightFor(chord, _currentPitch)` recebe esse acorde sem converter para o tom real. A mesma informacao alimenta o diagrama de teclado.

Evidencia: [cifra_screen.dart:293](C:/Users/nioti/cifra_band/lib/features/songs/presentation/screens/cifra_screen.dart:293), [cifra_screen.dart:1127](C:/Users/nioti/cifra_band/lib/features/songs/presentation/screens/cifra_screen.dart:1127).

Correcao recomendada: separar explicitamente acorde escrito/forma, acorde soante e tonalidade. Calcular graus pelo acorde soante; violao mostra a forma com capo; teclado mostra as notas reais. Validar baixos invertidos, transposicao e capo de 0 a 12.

### A02 - P1 - Downloads offline sao removidos sem aviso

**Confirmado por teste.** Ao salvar 21 setlists, ficam apenas 20 e a primeira deixa de estar disponivel. O usuario pode descobrir isso somente quando estiver sem internet.

Evidencia: [offline_setlist_service.dart:233](C:/Users/nioti/cifra_band/lib/core/services/offline_setlist_service.dart:233), uso de `skip(20)` para remover e `take(20)` para manter.

O payload e o indice sao gravados separadamente em SharedPreferences. Isso tambem exige cuidado com interrupcoes e downloads concorrentes. A documentacao do pacote nao recomenda esse armazenamento para dados criticos: [shared_preferences](https://pub.dev/packages/shared_preferences).

Correcao: downloads escolhidos pelo usuario nao devem ser tratados como cache descartavel. Usar armazenamento transacional ou arquivos com manifesto atomico, verificacao de integridade, aviso de espaco e exclusao explicita. Manter o isolamento por UID que ja existe neste servico.

### A03 - P1 - Favoritos e anotacoes podem atravessar contas no mesmo aparelho

**Confirmado no armazenamento e no fluxo de logout; nao exercitado em dois aparelhos.** Favoritos usam a chave global `favorite_songs`; anotacoes usam uma chave por musica, sem UID. O logout nao limpa nem troca esses namespaces.

Evidencias: [cifra_screen.dart:190](C:/Users/nioti/cifra_band/lib/features/songs/presentation/screens/cifra_screen.dart:190), [song_annotation_service.dart:8](C:/Users/nioti/cifra_band/lib/core/services/song_annotation_service.dart:8), [profile_screen.dart:72](C:/Users/nioti/cifra_band/lib/features/home/presentation/screens/profile_screen.dart:72).

Impacto: outra conta no mesmo telefone pode acessar anotacoes ou favoritos anteriores, inclusive conteudo salvo de uma biblioteca privada. Isso nao significa que o Firestore esteja aberto.

Correcao: chaves por UID, limpeza de estado em memoria ao trocar conta e migracao cuidadosa dos dados antigos. Nao atribuir automaticamente todo dado legado ao proximo usuario que entrar.

### A04 - P1 - Atualizacao obrigatoria pode ficar presa ao manifesto antigo

**Confirmado por leitura do controle de fluxo.** Quando existe `required_app_update` ainda obrigatorio para a versao instalada, o app abre esse dialogo e retorna antes de consultar o servidor.

Evidencia: [app_update_service.dart:106](C:/Users/nioti/cifra_band/lib/core/services/app_update_service.dart:106).

Risco: uma publicacao posterior nao substitui o manifesto local; se o APK antigo deixar de existir, o bloqueio pode persistir apontando para um download quebrado. Nao foi simulado download quebrado no tablet nesta auditoria.

Correcao: manter o bloqueio imediato, mas atualizar o manifesto em paralelo e substituir seus dados com uma resposta validada. Testar cache antigo, nova versao, perda de rede, link removido e retomada do download.

### A05 - P1 - YouTube ainda entra no caminho critico da cifra

**Confirmado no codigo; impacto exato na latencia autenticada ainda nao medido.** A tela desativa o recurso com `_youtubeGuidedEnabled = false`, mas o backend aguarda `resolveYoutubeReference` para cifras sem referencia, inclusive em caminhos de cache.

Evidencias: [cifra_screen.dart:43](C:/Users/nioti/cifra_band/lib/features/songs/presentation/screens/cifra_screen.dart:43), [server.js:5341](C:/Users/nioti/cifra_band/functions/server.js:5341), [server.js:5469](C:/Users/nioti/cifra_band/functions/server.js:5469).

A resolucao envolve varias tentativas de rede. Alem disso, encontrar uma cifra no cache do app dispara `_wakeRenderInBackground(apiUrl)` com a URL da busca completa, nao apenas um endpoint leve: [song_scraper_datasource.dart:84](C:/Users/nioti/cifra_band/lib/features/songs/data/datasources/song_scraper_datasource.dart:84).

Correcao: devolver imediatamente a cifra validada; resolver referencias opcionais fora desse caminho, com orcamento de tempo e feature flag. Aquecer somente um endpoint leve. E uma causa plausivel de lentidao, nao uma prova de que explica todos os relatos anteriores.

### A06 - P2 - Suporte filtra depois de limitar os registros

**Confirmado no codigo.** `/support-tickets` aplica `limit` antes dos filtros de status/tipo/prioridade e antes da ordenacao em memoria. Nao ha paginacao nesse fluxo.

Evidencia: [server.js:1008](C:/Users/nioti/cifra_band/functions/server.js:1008).

Com mais tickets que o limite, um chamado novo ou aberto pode nao aparecer. Atualmente contei apenas 4 tickets, portanto **esse limite nao explica sozinho qualquer ticket ausente hoje**.

Correcao: filtros e ordenacao no banco, indices correspondentes e cursor de paginacao. Testar mais de 100 tickets, inclusive chamados abertos fora da primeira pagina.

### A07 - P2 - Regra de aguardar resposta do suporte nao esta fechada em todos os caminhos

**Confirmado no contrato de escrita.** As regras permitem criar tickets diretamente com campos extras e nao verificam se ja existe atendimento aguardando resposta. O caminho HTTP faz verificacao antes da criacao, mas sem uma operacao atomica para essa exclusao mutua.

Evidencia: [firestore.rules:310](C:/Users/nioti/cifra_band/firestore.rules:310), endpoint `/feedback` em `functions/server.js`.

Impacto: cliente modificado pode abrir tickets repetidos e incluir campos que deveriam ser exclusivos do servidor no proprio ticket. Isso nao concede acesso global a outros usuarios. Requisicoes concorrentes tambem podem passar pela verificacao inicial.

Correcao: definir um unico caminho de escrita, lista permitida de campos, estado pendente transacional e chave de idempotencia. Envio de push deve ocorrer depois da persistencia sem tornar o sucesso do ticket dependente da entrega da notificacao.

### A08 - P2 - Compartilhamento e disponibilidade dos perfis de contatos

**Errata de 21/09/2026:** a afirmacao original de que o seletor consultava `users/{friendId}` estava incorreta para o HEAD auditado. A reinspecao do arquivo e de sua versao no Git confirmou o uso de `public_profiles`. O problema confirmado era ocultar silenciosamente contatos sem esse perfil publico ou com erro na leitura. A restricao de leitura de perfis privados entre ministerios continua correta e nao deve ser removida.

Evidencias: [setlist_detail_screen.dart:850](C:/Users/nioti/cifra_band/lib/features/setlist/presentation/screens/setlist_detail_screen.dart:850), [firestore.rules:97](C:/Users/nioti/cifra_band/firestore.rules:97).

Correcao local posterior: endpoint autorizado que retorna somente ID e nome dos amigos do chamador, inclusive contatos legados sem perfil publico. **Nao abrir a leitura de todos os documentos `users` para consertar a interface.** Ver [Etapa 1](C:/Users/nioti/cifra_band/docs/ESTABILIZACAO_ETAPA_1.md) para implementacao e testes, ainda sem publicacao.

### A09 - P2 - Musicas completas dentro do documento de escala limitam crescimento

**Risco estrutural confirmado; nao houve erro de tamanho reproduzido em producao.** Escalas mantem arrays de musicas sugeridas/aprovadas com conteudo. A reordenacao grava novamente o array completo, expondo alteracoes concorrentes a sobrescrita.

Evidencia: [event_detail_screen.dart:284](C:/Users/nioti/cifra_band/lib/features/home/presentation/screens/event_detail_screen.dart:284), `functions/lib/member-actions.js`.

O Firestore limita cada documento a 1 MiB, independentemente da quantidade de memoria do telefone: [limites oficiais](https://firebase.google.com/docs/firestore/quotas).

Correcao: musicas em subcolecao, ordem separada e controle transacional de versao. O modelo recente de musicas em subcolecao nas setlists pessoais e uma direcao melhor.

### A10 - P2 - Grafia de graus perde a estrutura da escala

**Confirmado por teste.** Em F# maior, o mapa retorna `Fdim` em vez de `E#dim` no setimo grau. A equivalencia enarmonica pode preservar alturas sonoras, mas a grafia ensina incorretamente a estrutura diatonica.

Evidencia: [chord_study_service.dart:85](C:/Users/nioti/cifra_band/lib/core/services/chord_study_service.dart:85).

As explicacoes tambem sao heuristicas por grau/qualidade, nao uma analise da progressao completa. Nao devem afirmar a funcao harmonica de todo acorde como certeza.

Correcao: representar letra e alteracao, nao somente indice cromatico. Cobrir maiores, menores, enarmonias, diminutos, meio-diminutos e inversoes. Apresentar funcoes fora do campo como possibilidades quando falta contexto.

### A11 - P2 - Historico oficial nao e imutavel

**Confirmado nas regras.** Administradores do ministerio podem criar, atualizar e excluir documentos em `official_songs/.../versions`. O historico funciona como recurso de interface, mas nao como trilha inviolavel de auditoria.

Evidencia: [firestore.rules:205](C:/Users/nioti/cifra_band/firestore.rules:205). O servico ja tem transacoes e controle de versao em parte dos fluxos, o que e positivo.

Correcao: versoes somente de criacao, campos de autor/data controlados e politica explicita de exclusao. Validar conflitos de edicao. O validador de acordes nao substitui revisao da letra, tom e arranjo.

### A12 - P2 - Catalogo interno deixa de crescer depois de 1.000 entradas

**Confirmado no codigo; limite ainda nao atingido.** A carga do catalogo usa `limit(1000)` sem paginacao e le conteudo integral para montar a busca. Contei 268 documentos atualmente.

Evidencia: [server.js:23](C:/Users/nioti/cifra_band/functions/server.js:23).

Correcao: indice de metadados separado, carga paginada ou mecanismo de busca indexado, sincronizacao incremental e metricas de cobertura. Este e um problema futuro de escala, nao evidencia de que 732 cifras estejam faltando hoje.

### A13 - P2 - Lembretes locais nao acompanham todas as mudancas de escala

**Confirmado por inspecao das chamadas.** Existe `cancelScheduleReminders`, mas nao encontrei uso no fluxo normal de mudanca/exclusao de escala. O agendamento depende de passagem pela tela/fluxo do app.

Evidencia: [schedule_reminder_service.dart:87](C:/Users/nioti/cifra_band/lib/core/services/schedule_reminder_service.dart:87).

Risco: lembretes antigos continuarem apos cancelamento ou alteracao. Exige teste em aparelho com notificacoes habilitadas.

Correcao: reconciliar lembretes pelo ID da escala, cancelar os obsoletos e reagendar ao alterar data, participacao ou conta. Push remoto e notificacao local precisam de responsabilidades separadas.

## 4. Arquitetura e qualidade de engenharia

| Camada | Situacao observada | Avaliacao |
|---|---|---|
| Aplicativo | Flutter/Dart, Riverpod, Firebase Auth/Firestore | Base adequada; mistura de UI e operacoes de dados em telas grandes |
| Descoberta | Catalogo local, sementes de hinos, Deezer/iTunes e ranking | Rapida nesta amostra; encontrar gravacao nao garante cifra |
| Cifras | Cache global, backend e provedores externos; validacao de conteudo | Boa separacao inicial, mas dependencias externas e metadados exigem diagnostico |
| Setlists | Documento pai, musicas em subcolecao, snapshots reativos | Melhoria recente relevante; compartilhamento/offline ainda requerem ajustes |
| Biblioteca oficial | Escopo por ministerio, editor, importacao, versoes | Funcional; historico mutavel e validacao musical limitada |
| Escalas | Dados compartilhados e acoes de membros mediadas pelo servidor | Melhor controle de acesso; arrays grandes e concorrencia sao riscos |
| Backend | Node/Express + Firebase Admin, publicado no Render | Funcional, mas `server.js` concentra cerca de 5.620 linhas |
| Persistencia local | SharedPreferences, cache Firestore e outros auxiliares | Download critico e anotacoes merecem armazenamento e isolamento mais fortes |
| Suporte | Painel HTML, tickets, logs e respostas | Util; corrigir paginacao e integridade da criacao |
| Distribuicao | APK GitHub, manifesto Render, instalacao Android | Funciona no cliente recente; bootstrap antigo e manifesto em cache sao limites |

Foram encontrados **74 arquivos Dart e aproximadamente 24.950 linhas em `lib`**. As maiores telas: cifra (2.636), evento (2.145), busca (1.877) e home (1.698). Tamanho nao prova defeito, mas aumenta o custo de testar e alterar sem regressao.

Recomendacao: extrair gradualmente casos de uso, contratos de dados e tratamento de erros. Evitar uma reescrita geral antes de estabilizar as falhas reproduzidas. Regras musicais duplicadas entre Dart e Node precisam compartilhar fixtures de teste.

## 5. Seguranca e permissoes

### O dono do SaaS nao e qualquer administrador

O backend da central global verifica o UID do proprietario, nao apenas `is_admin`: [server.js:901](C:/Users/nioti/cifra_band/functions/server.js:901). Criar um ministerio e virar administrador dele **nao concede esse acesso global** no fluxo auditado.

Isso e uma conclusao sobre os controles lidos e testados, nao uma garantia de ausencia de qualquer vulnerabilidade.

| Identidade | Acesso observado |
|---|---|
| Sem autenticacao | Login/recuperacao, endpoint publico de versao e resposta publica da API; nenhuma leitura Firestore liberada pelas regras atuais |
| Usuario autenticado | Proprio perfil e dados pessoais; leitura do cache global e perfis publicos; busca autenticada no backend; proprios tickets |
| Membro de ministerio | Leitura de dados autorizados desse ministerio e biblioteca oficial; acoes de resposta/voto pelo servidor |
| Administrador do ministerio | Gestao do seu ministerio, escalas, membros e biblioteca oficial; nao a central global |
| Proprietario do produto | Central global autorizada pelo UID fixado no backend; isso nao equivale a liberar todos os documentos diretamente no cliente |
| Backend com Admin SDK | Acesso privilegiado de servidor; depende de cada endpoint validar identidade e autorizacao |

Pontos positivos: negacao por padrao, bloqueio de autoedicao de `is_admin`/`church_id`, cache global sem escrita por cliente e regras especificas para musicas das setlists.

Pontos de endurecimento:

- Corrigir isolamento local de favoritos/anotacoes, nao apenas o banco remoto.
- Pessoas do mesmo ministerio podem ler o documento completo de perfil autorizado. Minimizar dados nesse documento: regras nao ocultam campos individuais. [Documentacao Firebase](https://firebase.google.com/docs/firestore/security/rules-fields).
- Revisar revogacao de sessao, limites contra abuso e limpeza dos buckets de rate limit em memoria. Limites locais ao processo reiniciam com o servidor.
- Considerar App Check como protecao complementar, sem substituir autenticacao/autorizacao.
- Nao foi encontrado segredo nos caminhos versionados pesquisados, mas isso nao substitui varredura de todo o historico Git.
- Logs/Crashlytics recebem contexto do usuario; definir retencao, acesso, redacao de mensagens e exclusao de dados. Nao certifico conformidade legal nesta auditoria.

### Dependencias e assinatura

`npm audit --omit=dev` encontrou **9 vulnerabilidades moderadas, zero altas e zero criticas** nas dependencias do backend. Ha dependencias transitivas de Firebase/Google, `qs` e `uuid`. A atualizacao sugerida inclui mudanca major; precisa de teste de compatibilidade. Presenca no audit nao prova exploracao pelo app.

Referencias: [qs e limites de arrays](https://github.com/advisories/GHSA-x5fp-wj9c-mxmx), [qs e DoS](https://github.com/advisories/GHSA-4mjr-xmp4-gh2g), [uuid e limites de buffer](https://github.com/advisories/GHSA-w5hq-g745-h8pq).

O APK publicado ainda usa identidade de assinatura de debug mantida para compatibilidade com instalacoes existentes. E uma divida de distribuicao. **Nao trocar a chave abruptamente**, pois atualizacoes precisam de identidade compativel. Planejar custodia, backup e migracao: [assinatura Android](https://developer.android.com/studio/publish/app-signing).

## 6. Resultados objetivos dos testes

| Verificacao | Resultado | Limite da conclusao |
|---|---|---|
| Flutter analyze | 0 erros, 0 warnings, 141 infos | O comando terminou com codigo 1 por apontamentos; nao esta totalmente limpo |
| Flutter test | 89/89 passaram | Testes existentes, nao todos os fluxos reais |
| Firestore/emulador e suite associada | 28/28 passaram | Regras/cenarios cobertos, nao pentest completo |
| Node: membros, conteudo, catalogo e versao | 18/18 passaram | Nao equivale a testar todos os scrapers em producao |
| Caracterizacao adicional | 3/3 reproduziram os defeitos descritos | As assercoes confirmam comportamento errado, nao aprovam sua qualidade |
| Cobertura LCOV | 2.047/4.180 linhas, 48,97% | Apenas 33 arquivos instrumentados; nao a cobertura de todo o app |

Os 141 infos incluem manutencao de APIs e estilo. Nao devem ser apresentados como 141 bugs em execucao.

Nao encontrei workflow em `.github` nesta copia. Recomendo CI bloqueando release em falha de testes, regras, analise e smoke test; canal de homologacao; checklist reproduzivel; e procedimento de recuperacao para manifestos/APKs incorretos.

## 7. Busca: 50 consultas reais

Foram usados 50 casos positivos misturando gospel, hinos e musicas antigas. O comparador espera titulo/artista normalizados; outras gravacoes podem conter a mesma composicao.

- **48/50 em primeiro lugar: 96% nesta amostra.**
- **48/50 entre os cinco primeiros.**
- **50/50 apareceram na lista completa**, com os dois restantes em 13o.
- Nenhuma resposta parcial sinalizada pelo servico nesta execucao.

| Consulta que falhou no top 5 | Posicao esperada | O que ficou acima |
|---|---:|---|
| alvo mais que a neve harpa crista | 13 | Outras gravacoes/interpretacoes da mesma musica |
| vencendo vem jesus harpa crista | 13 | Outras gravacoes/interpretacoes da mesma musica |

Isso confirma uma dificuldade de **priorizar o registro canonico da Harpa**, nao ausencia total da musica. A correcao precisa reconhecer numero do hino, colecao e identidade canonica sem tratar toda cover como erro.

| Medida das 50 consultas | Mediana | P95 | Minimo | Maximo |
|---|---:|---:|---:|---:|
| Primeiro resultado | 352 ms | 573 ms | 1 ms | 1.431 ms |
| Resultado consolidado | 937 ms | 1.433 ms | 416 ms | 1.522 ms |

P95 calculado por nearest-rank. Ambiente: computador desta auditoria e sua rede, nao aparelho Android. Resultado local de hino pode aparecer antes da rede. **Nao extrapolar 96% para todo o catalogo nem prometer 99%.** Esta rodada nao mede sistematicamente erros de digitacao, consultas negativas, artistas homonimos ou a abertura de 50 cifras.

Melhorias recomendadas: intencao artista/musica/hino, registro canonico por numero, agrupamento de versoes, relevancia acima de popularidade quando ha match exato, proveniencia e disponibilidade real da cifra. Manter regressao com erros como `jorgeve mayheus`, medleys e atribuicao errada de artista.

## 8. Latencia, cache e disponibilidade

Em oito consultas adicionais, a consolidacao ficou entre **730 e 1.352 ms**; repeticoes com cache ficaram entre **1 e 18 ms**. Esse cache e de descoberta musical, nao prova que uma cifra nao armazenada carregue nesse prazo.

Cinco requisicoes consecutivas a `/app-version` retornaram HTTP 200:

| Requisicao | Tempo |
|---|---:|
| 1 | 21.467 ms |
| 2 | 2.369 ms |
| 3 | 249 ms |
| 4 | 252 ms |
| 5 | 243 ms |

A diferenca e compativel com aquecimento do servico, mas o estado interno do Render nao foi instrumentado para provar cold start. O Render documenta suspensao de servicos gratuitos apos inatividade e atraso de retomada: [Render Free](https://render.com/docs/free).

Separar tres tempos no monitoramento: descobrir musica, obter cifra e baixar APK. Sao fluxos distintos. O aquecimento nao bloqueante ja existente ajuda, mas nao elimina a suspensao da infraestrutura.

Ainda faltam metricas reais por provedor: hit/miss de cache, duracao p50/p95, timeout, bloqueio, conteudo incompleto, erro de identidade e taxa de abertura bem-sucedida. Um `404` sozinho nao prova que nenhuma cifra existe na internet.

## 9. Infraestrutura e banco publicados

Leitura realizada em 15/09/2026, sem alterar documentos:

| Item | Resultado |
|---|---:|
| Regras publicadas iguais ao arquivo local | Sim |
| Ultima publicacao das regras consultadas | 13/09/2026 16:46:35 UTC |
| global_cifras | 268 documentos |
| setlists | 8 documentos |
| schedules | 6 documentos |
| support_tickets | 4 documentos |
| app_devices | 15 documentos |

Contagens de documentos nao equivalem a usuarios ativos, aparelhos unicos saudaveis ou quantidade de musicas nas subcolecoes. Nao foram publicados dados pessoais neste relatorio.

Firestore e Admin SDK possuem superficies distintas: as regras protegem clientes, mas os endpoints privilegiados precisam implementar suas proprias verificacoes. [Referencia oficial](https://firebase.google.com/docs/firestore/security/rules-fields).

## 10. Estado funcional por area

| Area | O que existe | Pendencia principal |
|---|---|---|
| Busca e artistas | Agregacao, ranking, resultados progressivos, perfil de artista | Harpa canonica, testes de intencao/typos e diferenciar musica de cifra disponivel |
| Cifra e transposicao | Tom, capo, simplificacao, leitura e diagramas | Corrigir forma versus som real; ampliar fixtures musicais e verificacao de letra |
| Setlists | Criacao, inclusao, contagem reativa por snapshots e compartilhamento | Compartilhamento entre ministerios, concorrencia e ensaio ponta a ponta |
| Offline | Download integral com verificacao de conteudo e escopo por conta | Remocao silenciosa, durabilidade e consistencia do indice |
| Historico | Registro e abertura de musicas | Cobrir exclusao, dados legados e permissao revogada em testes reais |
| Biblioteca oficial | Criacao/edicao/importacao, tom, metadados e versoes | Historico imutavel e conflitos/validacao de conteudo |
| Escalas | Equipe, disponibilidade, respostas, ensaio e repertorio | Tamanho do documento, alteracoes concorrentes e lembretes obsoletos |
| Perfil e senha | Perfil, autenticacao e recuperacao | Privacidade local e testes completos do link de recuperacao; spam nao foi auditado |
| Suporte | Tickets proprios, resposta do dono, diagnosticos e painel HTML | Paginacao, escrita atomica e controle de campos |
| Push | Registro de dispositivos e campanhas de atualizacao | Entrega e instalacao nao garantidas; clientes antigos precisam migrar |
| Atualizador Android | Manifesto, obrigatoriedade, download e instalador | Cache obrigatorio antigo e estrategia de assinatura/distribuicao |
| YouTube/Culto Guiado | Codigo parcial e dependencias presentes | Recurso desativado na tela; nao considerar funcionalidade entregue ao usuario |
| iOS | Estrutura de projeto existente | Sem evidencia de build/distribuicao validada; atualizador APK nao serve para iOS |

Nao realizei nova revisao visual de todas as telas em multiplos aparelhos. Os testes de widget existentes incluem popup em modo claro/escuro e texto grande, mas isso nao cobre toda a interface.

## 11. Atualizacao, notificacoes e tablet antigo

O manifesto publicado consultado indica **1.5.9, build 27, minimo 27 e atualizacao obrigatoria**. O APK tem 67.428.886 bytes, aproximadamente 64,3 MiB; inclui mais de uma arquitetura. O download completo depende da rede e do host, nao apenas do tempo do endpoint de versao.

Receber push **nao significa** ter o atualizador embutido. O codigo historico consultado em `v1.0.5` ainda identifica o app como `1.0.0+1` e nao possui o servico atual de atualizacao. Isso explica uma possibilidade concreta para o tablet, mas nao confirmei seu APK instalado fisicamente.

Um cliente antigo sem esse mecanismo precisa de uma instalacao de migracao por cima, com assinatura compativel, sem desinstalar e perder dados. Alterar o Render nao injeta codigo no APK ja instalado.

O push depende de token registrado/valido, permissao e entrega pelo sistema. Aceitacao pelo FCM nao comprova recebimento, leitura ou instalacao. O Android exige a participacao do usuario para a instalacao normal desse APK; nao prometer atualizacao silenciosa universal.

## 12. Plano recomendado de estabilizacao

### Etapa 1: proteger o uso no culto

1. Corrigir capo/graus/teclado com testes de propriedades e exemplos revisados.
2. Eliminar exclusao silenciosa de downloads e tornar gravacoes locais consistentes.
3. Separar favoritos/anotacoes por usuario e validar troca de conta.
4. Atualizar manifesto obrigatorio sem perder o bloqueio necessario.
5. Retirar YouTube da resposta critica de cifra enquanto o recurso estiver desativado.

Criterio de aceite: repertorio conferido abre em modo aviao, reinicio nao perde dados, tom real e diagramas concordam, uma nova release substitui um manifesto antigo e outra conta nao ve dados privados locais.

### Etapa 2: consistencia de banco e suporte

1. Corrigir seletor de compartilhamento usando perfil publico autorizado.
2. Paginar tickets e fechar caminhos alternativos de criacao/reenvio.
3. Tornar historico oficial somente de criacao e cobrir conflitos de edicao.
4. Separar musicas das escalas em subcolecoes e sincronizar lembretes.

Criterio de aceite: dois usuarios concorrentes nao sobrescrevem o repertorio, acesso revogado e tratado, mais de 100 tickets continuam acessiveis e nenhuma resposta de suporte pode ser forjada pelo cliente.

### Etapa 3: confiabilidade operacional e crescimento

1. CI, homologacao, smoke tests de release e assinatura sob custodia.
2. Atualizar dependencias vulneraveis com testes de regressao.
3. Instrumentar busca de cifra por etapa/provedor, sem expor dados sensiveis.
4. Expandir benchmark com hinos, artistas, typos, negativos, medleys e validacao de letra/tom.
5. Remover o teto silencioso do catalogo e rever disponibilidade da hospedagem.

So depois recomendo retomar YouTube/Culto Guiado como entrega maior. Nao ha base tecnica para calcular um percentual unico de conclusao: quantidade de funcionalidades e confiabilidade no culto sao medidas diferentes.

## 13. Evidencias locais e reproducao

Os artefatos de `build` sao temporarios/ignorados pelo Git e podem desaparecer em uma limpeza. O relatorio preserva os resultados principais.

- `build/audit-analyze-1.5.9.txt`: analise estatica.
- `build/audit-tests-1.5.9.txt` e `coverage/lcov.info`: testes Flutter e cobertura.
- `build/audit-rules-2026-09-15.txt`: suite de emulador.
- `build/audit-node-2026-09-15.txt`: suite Node.
- `build/audit-npm-backend.json`: dependencias.
- `build/search-benchmark.json`: 50 consultas, posicoes e tempos.
- `build/audit-response-times.json`: medidas adicionais e endpoint de versao.
- `build/audit-infra-2026-09-15.json`: contagens agregadas e comparacao de regras.
- `build/audit_characterization_test.dart` e `build/audit-characterization-2026-09-15.txt`: reproducao dos tres defeitos.

Comandos principais executados: `flutter analyze --no-pub`, `flutter test --no-pub --coverage --reporter expanded`, `firebase emulators:exec --only firestore --project demo-cifra-band "npm --prefix test/firestore test"`, `node --test test-member-actions.js test-content.js test-catalog-search.js test-update-version.js` no backend, `dart run tool/benchmark_music_search.dart` e `dart run tool/audit_response_times.dart`.

**Conclusao:** a proxima entrega deve ser uma versao de estabilizacao com criterios verificaveis, e nao mais funcionalidades acumuladas. Ha partes boas e testes aprovados, mas os defeitos reproduzidos de musica/offline e os riscos de isolamento/atualizacao precisam vir primeiro.
