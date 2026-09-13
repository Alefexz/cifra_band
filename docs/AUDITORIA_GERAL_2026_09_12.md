# Auditoria geral do Cifra Band
Nota de acompanhamento (13/09): este documento registra os achados anteriores as correcoes. A implementacao da versao 1.5.6 esta descrita em [RELEASE_1_5_6.md](RELEASE_1_5_6.md). Validacao atual: 72 testes Flutter, 22 testes de regras/push e 18 testes Node passaram. As consultas reais adicionais reconheceram "jorgeve mayheus" e "Jorge e Matheus" como Jorge & Mateus; Sol Nos Olhos passou pela URL direta correta. Recursos futuros e os limites de verificacao nao equivalem a uma certificacao de 100% do aplicativo.
Data: 12/09/2026. Base publicada: 1.5.5+23. Popup novo: implementado localmente, ainda sem release.

## 1. Conclusao executiva

O Cifra Band ja combina busca musical, cifras, repertorios, escalas, ensaios e suporte. O diferencial mais forte e a versao da musica preparada para a equipe da igreja, e nao competir apenas pelo tamanho do catalogo de streaming.

Minha avaliacao e de **beta funcional que ainda precisa de correcoes de seguranca e de exatidao musical antes de ampliar a distribuicao**. Os testes existentes passando nao comprovam seguranca integral: a auditoria adicional reproduziu acessos que deveriam ser restritos.

Prioridades: autorizacao e isolamento de dados; acordes e integridade da cifra; confiabilidade offline; entrega e abertura de notificacoes; somente depois expansao de recursos como YouTube sincronizado.

Nao atribuo uma porcentagem geral de qualidade ou de conclusao: nao existe inventario ponderado e aprovado que permita calcular isso com rigor. O numero 96% refere-se exclusivamente ao primeiro resultado correto na amostra anterior de 50 consultas, nao ao app inteiro.

## 2. O que foi efetivamente verificado

- Leitura dos fluxos Flutter, servicos centrais, regras Firestore, endpoints do backend e documentacao de releases.
- 60 testes Flutter passaram, incluindo 10 cenarios do popup novo.
- 13 testes Node passaram: conteudo, indice de pesquisa e versao do aplicativo.
- 18 testes existentes de Firestore e push passaram no emulador.
- Auditoria adicional de permissoes com seis operacoes em dados ficticios locais: cinco foram permitidas; uma leitura sem autenticacao foi corretamente negada. Uma das cinco e a alteracao de e-mail do perfil, que e uma precondicao do risco descrito em S1, nao uma escalada isolada.
- Nova medicao real de oito consultas de catalogo e cinco chamadas a /app-version.
- Inspecao real de tres paginas de cifras, incluindo repeticao do hino com o artista da ocorrencia de suporte.
- Reproducao de erros em acordes complexos por chamada ao proprio servico musical.
- APK debug compilado. Nenhuma instalacao por USB e nenhuma publicacao desta mudanca.
- Capturas Flutter em 390x844 e 320x640, tema claro/escuro e texto ampliado em 1,5x.

Limites: nenhum celular conectado foi detectado pelo ADB. Nao medi FPS, ANR, consumo de bateria, abertura fria da interface, rede 4G ou recebimento real de push. Nao alterei dados reais para testar permissoes. Nao executei carga de centenas de usuarios contra producao. A analise e abrangente por subsistema, mas nao certifica cada botao em todos os aparelhos.

## 3. Popup implementado

Ao selecionar uma musica nos resultados, o app agora mostra uma janela central com titulo, artista, capa quando disponivel e indicador de carregamento na cor do tema.

- A busca no campo de texto continua progressiva; o popup aparece ao pedir a cifra, nao a cada letra digitada.
- Apos seis segundos, informa demora sem afirmar uma causa que nao foi medida.
- Cancelar e voltar fecham a espera. Resultados tardios nao abrem outra tela.
- Cancelar abandona a espera da interface; nao aborta o trabalho que o servidor ja iniciou.
- Ha prazo maximo de 90 segundos para a operacao apresentada no popup.
- Erros permanecem visiveis com tentar novamente, fechar e reportar problema.
- Reportar abre feedback com musica, artista e mensagem preenchidos.
- Sucesso abre a cifra; nao adiciona uma confirmacao desnecessaria.
- O fechamento nao remove outro dialogo sobreposto, como uma atualizacao obrigatoria.
- Cifras da descoberta que ja estao completas em memoria continuam abrindo diretamente.

Arquivos: [lib/features/home/presentation/widgets/song_lookup_dialog.dart](C:/Users/nioti/cifra_band/lib/features/home/presentation/widgets/song_lookup_dialog.dart), [lib/features/home/presentation/screens/search_screen.dart](C:/Users/nioti/cifra_band/lib/features/home/presentation/screens/search_screen.dart:475), [test/song_lookup_dialog_test.dart](C:/Users/nioti/cifra_band/test/song_lookup_dialog_test.dart).

Este trabalho nao substituiu todos os SnackBars do aplicativo e nao mudou o FCM. A atualizacao obrigatoria e seu fluxo de download foram preservados. A janela de busca e os avisos de erro desse fluxo foram o escopo implementado.

## 4. Achados prioritarios

### S1. Autorizacao do suporte global usa um fallback editavel — alta prioridade

Em [functions/server.js](C:/Users/nioti/cifra_band/functions/server.js:930), o administrador global e identificado por `req.firebaseUser.email || userData.email`. O segundo valor vem do perfil Firestore, e o proprio usuario pode edita-lo.

Quando um token autenticado nao contem e-mail, esse fallback pode promover a informacao editavel a credencial de dono. A alteracao livre do e-mail foi reproduzida no emulador; o acesso ao endpoint real de suporte nao foi explorado. O impacto depende de um provedor/token sem e-mail estar disponivel, mas a autorizacao nao deve depender dessa condicao para ser segura.

Correcao: validar um UID fixo de proprietario configurado no servidor, ou claim administrativa emitida somente por backend confiavel; remover o fallback do perfil. Separar isso de admin do ministerio e testar usuario comum, admin de outra igreja, token sem e-mail e perfil com e-mail falsificado.

### S2. Entrada em ministerio sem comprovar convite — confirmada localmente

[firestore.rules](C:/Users/nioti/cifra_band/firestore.rules:64) permite mudar o proprio church_id para uma string, mantendo is_admin false, sem validar convite. No emulador, um usuario entrou em uma igreja conhecendo apenas o ID. Isso nao o torna dono do SaaS, mas pode liberar dados e acoes de membro.

Correcao: entrada por endpoint autenticado que valide convite e grave vinculo; proibir a alteracao direta desse campo pelo cliente. A migracao precisa manter criar ministerio, entrar, sair e remover membro funcionando.

### S3. Perfil de outra equipe e lista de amigos expostos — confirmada localmente

[firestore.rules](C:/Users/nioti/cifra_band/firestore.rules:106) libera leitura de um perfil autenticado quando o documento possui friendCode string. Essa leitura inclui o documento inteiro, nao apenas nome/codigo: no teste foi possivel ler um token FCM ficticio. [firestore.rules](C:/Users/nioti/cifra_band/firestore.rules:99) tambem permitiu substituir a lista de amigos de outro usuario desde que o autor se incluisse nela.

Correcao: separar perfil publico minimo de dados privados; manter tokens em local privado; implementar convite/aceite de amizade e limitar alteracoes ao vinculo envolvido. Nao basta esconder campos na tela.

### S4. Membro consegue alterar a resposta de outro musico — confirmada localmente

[firestore.rules](C:/Users/nioti/cifra_band/firestore.rules:160) restringe os nomes dos campos alterados, mas nao o conteudo interno de team_assignments e suggested_songs. Um membro da escala alterou a resposta de outro integrante em dados ficticios.

Correcao: documentos por membro/voto com dono explicito ou endpoints transacionais que validem a alteracao individual. Testar recusas, aceite, votos, sugestoes, remocao e aprovacoes com duas contas.

### S5. Cifras em songs nao herdam a privacidade da setlist — identificado no codigo

[firestore.rules](C:/Users/nioti/cifra_band/firestore.rules:280) permite leitura e criacao em songs para qualquer conta autenticada. A protecao da setlist nao protege automaticamente os documentos de musica referenciados. Se esses documentos carregarem conteudo ou observacoes privadas, eles ficam acessiveis a outras contas.

Correcao: separar catalogo publico de arranjos privados e atrelar leitura ao proprietario, colaboradores ou ministerio. Rever validacao/tamanho dos documentos e protecao contra escrita abusiva.

### M1. Diagramas e notas ainda erram extensoes — reproduzido

[lib/core/services/chord_study_service.dart](C:/Users/nioti/cifra_band/lib/core/services/chord_study_service.dart:367) e [lib/core/services/chord_study_service.dart](C:/Users/nioti/cifra_band/lib/core/services/chord_study_service.dart:422):

| Entrada | Resultado observado | Problema |
| --- | --- | --- |
| C | C, E, G; forma C | Caso basico consistente |
| C7M | C, E, G, B; forma C7M | Caso basico consistente |
| D/F# | F#, D, A; forma D/F# | Notas consistentes com a inversao |
| D7/F# | Notas incluem C, mas forma D/F# | Diagrama perde a setima |
| C7(b9) | C, E, G, A#, D; forma C7 | Nona deveria ser bemol; forma ignora alteracao |
| C7(#9) | Mesmas notas de C7(b9); forma C7 | Nona sustenida nao e diferenciada |
| Cdim7 | Forma C7 | Acorde diminuto usa diagrama dominante |
| Am7M | Notas A, C, E, G#; forma A7M e rotulo maior | Diagrama/explicacao mudam a qualidade menor |

A grafia enarmonica isolada, como A# em vez de Bb, nao altera a altura sonora; o erro principal aqui e perder alteracoes ou trocar a qualidade. Nao e apenas uma questao estetica.

Correcao: parser que represente fundamental, qualidade, extensoes, alteracoes e baixo separadamente; banco de formas revisadas; validar as notas de cada forma contra o acorde solicitado. Quando nao houver forma exata, informar isso em vez de simplificar silenciosamente. Revisao musical humana e testes com teclado e violao sao necessarios.

### D1. Offline nao e isolado por conta — identificado no codigo

[lib/core/services/offline_setlist_service.dart](C:/Users/nioti/cifra_band/lib/core/services/offline_setlist_service.dart:35) usa chaves por scheduleId, sem UID. [lib/features/home/presentation/screens/profile_screen.dart](C:/Users/nioti/cifra_band/lib/features/home/presentation/screens/profile_screen.dart:71) faz logout sem limpar ou separar esse armazenamento. Outra conta no mesmo aparelho pode encontrar os downloads anteriores.

Tambem ha indice limitado a 20 resumos sem remocao correspondente dos arquivos antigos, e o selo de salvo verifica existencia da chave, nao integridade/atualidade do conteudo.

Correcao: armazenamento por UID, migracao cuidadosa, verificacao de versao/conteudo, limpeza controlada e teste de troca de conta. Nao apagar downloads existentes sem planejar a migracao.

### D2. Versao oficial e historico nao sao atomicos — identificado no codigo

[lib/core/services/official_library_service.dart](C:/Users/nioti/cifra_band/lib/core/services/official_library_service.dart:154) le a versao, grava a cifra e depois grava versions/vN em operacoes separadas. Duas edicoes podem disputar o mesmo numero, ou uma falha deixar cifra atualizada sem historico.

Correcao: transacao com incremento da versao e registro historico no mesmo commit; UI de conflito. A cifra oficial tambem e consultada depois de buscar a cifra externa, entao uma falha externa pode impedir aproveitar uma versao ja existente.

### N1. Notificacao chega, mas faltam destinos de abertura — identificado no codigo

Em [lib/main.dart](C:/Users/nioti/cifra_band/lib/main.dart:183), o tratamento de abertura atua em app_update_available. Nao encontrei tratamento completo de getInitialMessage e destinos de suporte/escala. A inicializacao local em [lib/core/services/push_notification_service.dart](C:/Users/nioti/cifra_band/lib/core/services/push_notification_service.dart:217) nao registra callback de toque.

Correcao: normalizar payloads, tratar aplicativo aberto, em segundo plano e iniciado pelo toque; abrir o ticket/escala certo, revalidar permissao e lidar com item removido. A documentacao oficial descreve os caminhos de recebimento e interacao. [Firebase FCM](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

O logout tambem precisa desvincular o token da conta anterior. O perfil conserva fcmTokens, e pode haver notificacao da conta antiga num aparelho compartilhado; o risco foi identificado por leitura, nao por recebimento real em dois celulares.

### N2. Download pode ficar esperando apos os cabecalhos — identificado no codigo

[lib/core/services/app_update_service.dart](C:/Users/nioti/cifra_band/lib/core/services/app_update_service.dart:299) limita a chegada inicial da resposta, mas nao impõe timeout de inatividade ao stream inteiro. Um arquivo nao vazio e aceito sem conferir o tamanho esperado ou um hash fornecido pelo manifesto. A assinatura do Android continua sendo uma protecao, mas nao substitui diagnostico de download incompleto.

Correcao: timeout por inatividade, limite total, limpeza de arquivo parcial, validacao de tamanho/hash, cancelamento e tentativa novamente. A obrigatoriedade de versao depende de obter o manifesto remoto; nao equivale a bloqueio persistido offline.

### Q1. Validador de letra nao comprova musica completa

[lib/features/songs/domain/song_content_quality.dart](C:/Users/nioti/cifra_band/lib/features/songs/domain/song_content_quality.dart) exige pelo menos duas linhas de letra, seis palavras e dois acordes. Isso filtra tablatura isolada, mas um trecho parcial pode passar. O backend tambem usa heuristicas estruturais.

Correcao: distinguir conteudo utilizavel de cifra completa, manter fonte/versao, detectar paginas truncadas e testar secoes esperadas em amostras revisadas. Nao chamar uma heuristica de garantia de exatidao musical.

### Q2. Importacao pode interpretar letra como metadado

[lib/core/services/official_library_service.dart](C:/Users/nioti/cifra_band/lib/core/services/official_library_service.dart) tenta inferir titulo/artista a partir de linhas sem acordes e infere tom quando ele nao foi informado. Essas suposicoes precisam ser apresentadas como rascunho a confirmar, nunca como certeza.

Correcao: previa lado a lado, campos inferidos identificados e confirmacao antes de oficializar. Parser ChordPro e identificador canonico de musica devem preceder expansao de importadores.

## 5. Tempos de resposta medidos agora

Medicao em 12/09/2026, por esta maquina/rede. Catalogos Deezer e Apple, sem token Firebase no benchmark. O primeiro resultado do hino 545 vem de metadados locais. Os tempos de cache sao de repeticao na mesma instancia do servico; 0 ms significa abaixo da resolucao da medicao.

| Consulta | Primeiro resultado | Lista concluida | Repeticao em cache |
| --- | ---: | ---: | ---: |
| Porque Ele Vive 545 | 17 ms | 642 ms | 9 ms |
| Bondade de Deus + Isaias Saad | 85 ms | 384 ms | 4 ms |
| Galileu + Fernandinho | 105 ms | 372 ms | 10 ms |
| Aquieta Minhalma + Ministerio Zoe | 85 ms | 419 ms | <1 ms |
| Fernandinho | 88 ms | 542 ms | 10 ms |
| Alvo Mais Que a Neve + Harpa Crista | 98 ms | 639 ms | 10 ms |
| Tempo Perdido + Legiao Urbana | 82 ms | 323 ms | 5 ms |
| bonddade de deus, com erro de digitacao | 573 ms | 575 ms | 5 ms |

Nenhuma destas oito consultas sinalizou fonte parcialmente indisponivel. Sao tempos do servico, sem somar o debounce de 450 ms do campo e o trabalho de renderizacao do aparelho.

Cinco chamadas sequenciais a /app-version retornaram HTTP 200: **21493, 2095, 274, 281 e 264 ms**. A primeira teve latencia elevada; sem instrumentacao do estado do servidor, nao afirmo que toda ela foi cold start.

O Render documenta que instancias Free suspendem apos 15 minutos sem trafego e levam aproximadamente um minuto para reativar. Isso e um risco para uso ao vivo, independentemente de popup. [Render Free](https://render.com/docs/free).

### Busca nao e abertura de cifra

O fluxo tem etapas diferentes:

1. Texto digitado -> debounce -> Deezer/Apple/indice global -> ranking.
2. Clique -> cache global Firestore (timeout de 5 s) -> /searchSong quando necessario.
3. Backend -> cache de processo/global -> paginas/fontes alternativas -> validacao de letra e acordes.
4. App -> consulta de versao oficial da igreja -> abertura da cifra.
5. Historico e dados de uso sao gravados separadamente.

O servico de cifra tem espera inicial de 45 s e uma tentativa de recuperacao de ate 60 s em parte do fluxo. A verificacao de atualizacao tenta quatro vezes, com 25 s por tentativa e atrasos de 6, 15 e 30 s: ate aproximadamente 151 s mais processamento, em caso de falhas sucessivas. Isso ocorre em segundo plano, nao deve bloquear a primeira tela.

Nao medi download do APK nem abertura completa autenticada de cifra em producao nesta rodada. O APK publicado anterior tem cerca de 67,3 MB; conexao de download e catalogo musical sao gargalos diferentes.

### Paginas reais inspecionadas

| Fonte consultada diretamente | Tempo | Tom extraido | Linhas de letra | Acordes reconhecidos |
| --- | ---: | --- | ---: | ---: |
| Porque Ele Vive - 545 / Harpa Crista | 315 ms | A | 42 | 93 |
| Mesma pagina, pedido Nossa Harpa / HC 545 | 69 ms | A | 42 | 93 |
| Galileu / Fernandinho | 152 ms | Bbm | 55 | 124 |
| Bondade de Deus / Isaias Saad | 179 ms | D | 50 | 128 |

A pagina foi passada diretamente ao extrator: isso nao mede quanto o mecanismo leva para descobrir a URL. O caso Nossa Harpa foi aceito quando a URL correta foi fornecida, mas isso nao comprova que o caminho automatico de descoberta corrigiu aquele ticket. Nenhum ticket foi respondido ou encerrado por esta auditoria.

### Amostra anterior de 50 musicas

Na rodada anterior: 50/50 titulos/artistas esperados apareceram, 48/50 em primeiro lugar. Os dois hinos em 13o continuam uma limitacao de ranking de colecao versus interprete. Os 50 casos nao foram repetidos nesta auditoria. Relatorio: [docs/TESTE_50_MUSICAS_1_5_5.md](C:/Users/nioti/cifra_band/docs/TESTE_50_MUSICAS_1_5_5.md).

## 6. Inventario funcional por area

Presenca de codigo nao equivale a validacao completa em aparelho. A coluna de risco indica o que ainda deve ser homologado.

| Area/tela | O que faz e principais acoes | Dados e dependencias | Estado/risco |
| --- | --- | --- | --- |
| Entrada/onboarding | Entrar, criar conta, recuperar senha | Firebase Auth, users | Codigo presente; falta jornada de exclusao |
| Home | Resumo, equipe, atalhos, navegacao por abas | users, ministries, schedules | Fluxos dependem de papel e vinculo |
| Perfil | Nome, funcoes, senha, sair, atalhos | Auth/users | Logout sem limpeza privada completa; tema inconsistente entre telas |
| Criar ministerio | Nome, criacao da equipe e convite | ministries, invites, users | Migrar junto da correcao de ingresso |
| Adicionar amigo | Procurar codigo, vincular contato | users/friends | Regras permissivas confirmadas |
| Busca/Repertorio | Digitar, filtrar musicas/albuns/artistas, descoberta e recentes | Deezer, Apple, indice global | 96% top1 na amostra anterior, nao universal |
| Perfil do artista na busca | Ver musicas e albuns; abrir album | Catalogo do provedor correto | Carregamento sob demanda testado |
| Abrir cifra | Buscar conteudo e versao oficial; cancelar/erro/suporte | Cache, Render, biblioteca | Popup novo testado; nao evita indisponibilidade |
| Tela de cifra | Transpor, fonte, rolagem, capo, simplificada, claro/palco | TransposerEngine e SongModel | Revisar tons inferidos e acordes complexos |
| Acordes/graus | Forma de violao, teclado, notas e explicacoes | ChordStudyService | Erros concretos reproduzidos |
| Anotacoes pessoais | Salvar observacoes de estudo | SongAnnotationService | Homologar troca de conta e offline |
| Favoritos | Favoritar, listar e reabrir | Biblioteca do usuario | Testar remoção/sincronizacao em dois aparelhos |
| Historico | Registrar abertura, reabrir e excluir | users/played_history | Regrava cifra e consulta ate 40 docs por abertura; custo cresce |
| Setlists | Criar, listar proprias/compartilhadas | setlists | Consulta OR e gravacao atomica cobertas pelo emulador |
| Detalhe de setlist | Abrir, adicionar/remover musica, compartilhar | setlists + songs | Privacidade de songs precisa revisao |
| Revisar/adicionar cifra | Tom, capo, referencia, BPM, observacao e salvar | SongDestination; batch Firestore | Destinos escala/setlist separados; falta E2E real nesta rodada |
| Biblioteca oficial | Listar, criar, editar, arquivar, historico | ministries/official_songs | Historico nao atomico; qualidade depende de revisao |
| Importacao colada | Ler texto, inferir campos, validar acordes | Parser local | Inferencias precisam confirmacao explicita |
| Escalas | Agenda, criacao e equipe | schedules/users | Respostas individuais nao estao isoladas nas regras |
| Disponibilidade | Marcar datas indisponiveis | users/availability | N leituras por integrantes; validar conflitos no servidor |
| Detalhe da escala | Aceitar/recusar, sugestoes/votos, aprovar repertorio | schedules + notificacoes | Regras internas de listas/mapas precisam reforco |
| Ensaios | Status ja ensaiei e anotacoes | rehearsal_status | Homologar identidade imutavel e concorrencia |
| Modo culto | Navegar musicas da escala, leitura em sequencia | Lista de SongModels | Bom diferencial; testar aparelho em modo aviao |
| Download offline | Salvar, listar, abrir/remover setlist | SharedPreferences | Sem isolamento por usuario e sem manifesto de integridade |
| Exportacao da escala | WhatsApp, copiar texto, gerar PDF | share_plus/pdf/arquivos locais | Codigo presente; PDF/WhatsApp nao homologados em celular aqui |
| Feedback | Criar ticket com contexto/logs | support_tickets e servicos | Dados pessoais precisam politica/retencao |
| Meu suporte | Ler conversa, resposta e status | Endpoints autenticados | Timeout 15 s pode falhar ao reativar Render |
| Central do dono | Listar, responder, resolver/reabrir/fechar | Backend/Admin SDK; painel HTML | Prioridade S1; nao confiar em e-mail editavel |
| Atualizacoes | Verificar, popup obrigatorio/opcional, baixar e instalar | Render/GitHub/instalador Android | Reforcar stream, integridade e bloqueio persistido |
| Push | Escalas, suporte, versao do app | FCM, tokens por aparelho | Faltam destinos gerais de toque e desvinculo no logout |
| YouTube/Culto Guiado | Codigo de player e sincronizacao | youtube_player, referencias/secoes | Flag _youtubeGuidedEnabled=false; NAO contar como recurso ativo |
| IA de atendimento/deteccao de tom | Ideias do planejamento | Sem fluxo operacional comprovado | Nao considerar implementadas |

As telas principais estao em lib/features/home, lib/features/songs e lib/features/setlist. Rotas: [lib/config/routes/app_router.dart](C:/Users/nioti/cifra_band/lib/config/routes/app_router.dart). Backend principal: [functions/server.js](C:/Users/nioti/cifra_band/functions/server.js). Regras: [firestore.rules](C:/Users/nioti/cifra_band/firestore.rules).

## 7. Backend e banco: qualidade e capacidade

Pontos positivos: token Firebase nos endpoints protegidos, rate limits, coalescencia de buscas simultaneas, cache global, verificacao estrutural de conteudo e trabalho de push com lease persistida.

Limites: servidor concentra milhares de linhas e varias responsabilidades; consultas externas sao executadas em etapas e podem acumular latencia; a disponibilidade depende de sites de terceiros; cache por texto de artista/titulo nao e uma identidade canonica de composicao/arranjo.

O indice de trechos cobre ate 1000 documentos e atualiza por processo a cada hora. Isso nao e busca por letras de toda a internet. A contagem de 259 documentos veio da verificacao anterior; nao a apresente como contagem em tempo real indefinidamente.

Melhorias: identificador canonico de obra e versao; cache com proveniencia, qualidade e revisao; telemetria por etapa/fonte; paginas de fontes em fixtures de regressao; circuit breaker e orcamento total de tempo; modularizar busca, suporte, notificacoes e atualizacao sem reescrever tudo de uma vez.

## 8. Comparacao com concorrentes e referencias

Comparacao de recursos publicamente documentados, nao benchmark de latencia dos concorrentes nem acesso aos algoritmos privados. Sem comparar precos.

| Produto | O que foi verificado | Aprendizado para Cifra Band |
| --- | --- | --- |
| Cifra Club | Listas sincronizadas e acesso offline no aplicativo; catalogo por artista/titulo e ferramentas de cifra | Confiabilidade da biblioteca e abertura direta precisam preceder recursos vistosos |
| Deezer | Busca por letras foi anunciada para trechos de pelo menos quatro palavras e faixas com letras disponiveis | Separar metadados, interpretacao e trechos; mostrar correspondencia sem inventar cobertura universal |
| Planning Center Services | Planejamento do culto, escalas, ensaios e integracoes para cifras/audio | A equipe, a versao de ensaio e o repertorio aprovado devem ser o centro do produto |
| SongbookPro | Importacao ChordPro/OnSong/PDF, transposicao/capo, metronomo, anotacoes e biblioteca para grupos | Melhorar leitura em tablet, formatos de importacao e anotacao consistente com o layout |

Fontes: [Cifra Club: listas e offline](https://suporte.cifraclub.com.br/pt-BR/support/solutions/articles/64000253540-como-acessar-minhas-listas-em-qualquer-dispositivo), [Deezer: busca por letras](https://newsroom-deezer.com/2021/01/find-my-song-deezer-introduces-search-by-lyrics-2/), [Planning Center](https://www.planningcenter.com/use-cases/worship-planning), [SongbookPro](https://songbook-pro.com/).

Minha recomendacao, como inferencia dessa comparacao: posicionar o Cifra Band como repertorio confiavel da igreja, pronto antes do culto, com estudo para teclado e violao. Copiar um feed de streaming nao resolve a principal dor de quem precisa tocar sem falhar.

## 9. Notificacoes: proxima etapa recomendada

- Busca de cifra: popup implementado nesta entrega.
- Sucesso simples (favoritar/salvar): aviso discreto, sem interromper a leitura.
- Erro que exige decisao: popup com acao objetiva e contexto preservado.
- Resposta de suporte: aviso com abrir ticket.
- Escala: aviso com abrir evento, respeitando a conta atual.
- Atualizacao: manter seu fluxo especifico; obrigatoriedade apenas no manifesto para versoes que precisam dela.
- Modo palco: nao sobrepor a cifra com avisos rotineiros enquanto a pessoa toca; concentrar em caixa de entrada/badge.
- Caixa de entrada persistente: lidas/nao lidas, deduplicacao por evento e preferencias por categoria.
- Medir envio aceito pelo FCM separadamente de abertura pelo usuario. Ausencia de abertura nao prova falha na entrega.

Nao e adequado prometer popup no centro da tela com o app fechado: nesse estado a apresentacao depende do sistema operacional e das permissoes. O popup descrito aqui e interno ao aplicativo.

## 10. Plano recomendado, em ordem

### Etapa A — seguranca antes de distribuicao maior
Corrigir S1 a S5 e desvinculo de tokens. Separar UID do dono do papel de admin da igreja. Migrar ingresso e amizades com testes de regressao. Criterio de aceite: operacoes indevidas da auditoria passam a ser negadas, sem quebrar criacao/ingresso/escala/setlist legitimos.

### Etapa B — cifra musicalmente confiavel
Corrigir parser/formas dos acordes e seus testes; mostrar fonte e versao; criar catalogo de hinos por numero sem tratar interpretacao e obra como a mesma coisa. Testar titulo, busca da URL, letra, tom/capo e diagrama em uma unica jornada. Criterio: amostra revisada por tecladista e violonista, nao apenas retorno HTTP 200.

### Etapa C — prontidao para culto
Offline por conta e com integridade; versao oficial atomica; baixar todas as cifras aprovadas antes do evento; avisar se falta alguma. Criterio: abrir app e repertorio completo em modo aviao apos reinicio, com troca de conta testada.

### Etapa D — operacao e comunicacao
Toque de push abre destino correto; inbox; preferencias; diagnostico por requestId e duracao de etapa; download com integridade. Criterio: homologar primeiro plano, segundo plano, app encerrado e permissao negada em celulares reais.

### Etapa E — publicacao e expansao
Privacidade, exclusao de conta/dados, retencao de logs, revisao de fontes/licencas, assinatura de producao e AAB. O fluxo de APK beta e separado da estrategia da Play Store. A politica da Play exige caminho para solicitar exclusao no app e recurso web quando ha criacao de conta. [Google Play](https://support.google.com/googleplay/android-developer/answer/13327111).

Nao localizei fluxo de exclusao no codigo; ele ainda aparece como tarefa no planejamento. Depois desses fundamentos: ChordPro, biblioteca de hinos mais ampla, ferramentas de ensaio, YouTube/Culto Guiado com marcacoes revisadas e IA de suporte com escalonamento humano.

## 11. Metricas para acompanhar

| Metrica | Como medir | Meta inicial proposta, nao resultado atual |
| --- | --- | --- |
| Busca top1/top5 | Conjunto fixo com respostas esperadas e negativas | >=95% top1 na amostra revisada, expandindo generos/consultas |
| Abertura de cifra completa | Titulo/artista + conteudo validado + fonte | Separada da taxa de achar metadados |
| Tempo de primeira resposta | p50/p95 por cache/rede e aparelho | p95 <1,5 s para catalogo com rede adequada |
| Cifra em cache/offline | Toque ate conteudo utilizavel | p95 <1 s em aparelho alvo |
| Backend aquecido | p50/p95 por endpoint | Alerta quando degradar, sem usar /app-version como prova de busca rapida |
| Estabilidade | Crash-free users, ANR, frames lentos | Estabelecer baseline real antes de declarar porcentagem |
| Suporte | Tempo da primeira resposta e reincidencia | Priorizacao por impacto, dispositivo e versao |
| Notificacoes | FCM aceito, toque, destino valido | Sem duplicatas e sem dados da conta anterior |
| Seguranca | Testes por papel e tentativa indevida | Negar todas as operacoes indevidas mapeadas |

O Crashlytics esta integrado, mas todos os FlutterError sao registrados como fatais no main. Separar falha recuperavel de crash real melhora a qualidade das metricas. Logs atuais incluem UID/e-mail: limitar acesso, redigir dados sensiveis e definir retencao.

## 12. Evidencias e reproducao

- Popup: [test/song_lookup_dialog_test.dart](C:/Users/nioti/cifra_band/test/song_lookup_dialog_test.dart).
- Medicoes: [tool/audit_response_times.dart](C:/Users/nioti/cifra_band/tool/audit_response_times.dart) -> build/audit-response-times.json.
- Extracao de paginas: [tool/audit_cifra_sources.cjs](C:/Users/nioti/cifra_band/tool/audit_cifra_sources.cjs).
- Notas/formas observadas: [tool/audit_chord_notes.dart](C:/Users/nioti/cifra_band/tool/audit_chord_notes.dart).
- Auditoria de regras: [tool/audit_firestore_risks.cjs](C:/Users/nioti/cifra_band/tool/audit_firestore_risks.cjs); exige emulador local e projeto demo.
- Suite anterior: flutter test --no-pub; Node test-content/test-catalog-search/test-update-version; npm --prefix test/firestore test dentro de emulators:exec.
- Analise estatica geral inicial: 155 apontamentos informativos anteriores, sem erros ou warnings. Os arquivos da mudanca foram analisados separadamente sem apontamentos.
- Captura de busca: [build/popup-busca.png](C:/Users/nioti/cifra_band/build/popup-busca.png); acessibilidade: build/popup-dark.png e build/popup-light.png. Capturas controladas de widget, nao do celular do usuario.

As falhas deste relatorio, fora o fluxo do popup, **nao foram corrigidas nem publicadas nesta entrega**. Nenhuma regra de producao foi alterada. A versao publicada continua 1.5.5+23.
