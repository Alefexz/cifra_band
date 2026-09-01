# Plano do Cifra Band: beta, escalabilidade e publicacao

Atualizado em: 2026-08-31

## Estado atual

O Cifra Band esta pronto para um beta controlado em igreja. O app ja cobre o fluxo principal:

- Criar ministerio.
- Entrar no ministerio por codigo.
- Criar culto/escala.
- Adicionar equipe.
- Aceitar ou recusar escala.
- Sugerir louvor.
- Aprovar musicas para o repertorio oficial.
- Reordenar setlist do culto.
- Abrir cifras.
- Transpor tons maiores e menores.
- Usar modo simplificado.
- Usar modo palco e modo claro.
- Baixar setlist offline.
- Receber notificacoes push.
- Registrar historico das ultimas 20 musicas.
- Marcar disponibilidade.

Notas atuais:

- Beta real em igreja: 92%.
- Experiencia de cifra e palco: 88%.
- Gestao de escala e equipe: 90%.
- Seguranca para beta fechado: 84%.
- Pronto para SaaS publico: 76%.
- Potencial comercial no nicho: 93%.

## Origem das cifras

O fluxo de cifra funciona assim:

1. A busca visual usa a API publica do iTunes/Apple para encontrar nome, artista, capa e metadados.
2. Ao escolher a musica, o app chama a API propria no Render em `/searchSong`.
3. O app tenta ler primeiro o cache global no Firestore, na colecao `global_cifras`.
4. Se a cifra existir no cache global, ela abre rapidamente.
5. Se nao existir, a API no Render busca a cifra no Cifra Club usando scraping com `axios` e `cheerio`.
6. A API extrai titulo, artista, tom, forma, capo e conteudo.
7. A API salva o resultado em `global_cifras`.
8. O app exibe a cifra e pode salvar em historico, biblioteca e setlist offline.

Risco principal: scraping do Cifra Club funciona para beta, mas nao deve ser o unico pilar de um SaaS grande. O plano de evolucao precisa incluir importacao manual de cifras, edicao de cifras e biblioteca propria por ministerio.

## Checklist para o beta de domingo

Antes de mandar para colegas:

- Instalar o APK em pelo menos dois celulares.
- Fazer login com contas diferentes.
- Conferir se cada aparelho salva token FCM no Firestore.
- Criar uma escala real.
- Escalar um musico.
- Confirmar se o musico recebe notificacao.
- Fazer o musico aceitar a escala.
- Confirmar se o admin recebe notificacao de aceite.
- Fazer o musico recusar a escala.
- Confirmar se o admin recebe notificacao de recusa.
- Sugerir uma musica.
- Aprovar a musica.
- Reordenar a setlist.
- Abrir modo culto em retrato e paisagem.
- Testar swipe lateral em retrato.
- Baixar setlist offline.
- Desligar internet e abrir a setlist offline.
- Testar uma cifra com tom menor, como Galileu.
- Testar modo simplificado.
- Testar modo claro e modo palco.

Mensagem para enviar aos testadores:

> Este e um APK beta do Cifra Band. Ao instalar, talvez o Android avise que veio de fora da Play Store. Isso e normal para teste fechado. Se encontrar algum erro, tire print da tela e me envie junto com o que voce estava tentando fazer.

## Plano de segunda-feira em diante

### Fase 1: estabilizacao do beta

Objetivo: transformar o teste da igreja em dados uteis.

- Criar uma tela simples de "Enviar feedback".
- Criar campo para o usuario descrever o problema.
- Capturar automaticamente uid, email, versao do app, modelo do aparelho e horario.
- Salvar feedback em `support_tickets` no Firestore.
- Adicionar severidade automatica: bug critico, duvida, sugestao, problema de cifra, problema de notificacao.
- Melhorar mensagens de erro na busca de cifra.
- Mostrar estado de cold start: "Acordando servidor, pode levar alguns segundos".
- Mostrar selo "Setlist baixada" e data do ultimo download offline.
- Revisar todos os fluxos com usuario membro e admin.

### Fase 2: logs e observabilidade

Objetivo: fazer problemas reais chegarem com contexto tecnico.

- Usar Crashlytics para quedas e erros fatais.
- Adicionar `FirebaseCrashlytics.instance.log(...)` nos fluxos principais.
- Adicionar custom keys: `uid`, `church_id`, `screen`, `schedule_id`, `song_title`, `action`.
- Registrar erros tratados da API de cifra e push.
- Criar um painel simples no Firestore para tickets abertos.
- Separar erros reais de duvidas de uso.

Referencia oficial: https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports

### Fase 3: suporte com IA

Objetivo: como voce esta sozinho, a IA deve resolver o basico e so escalar o que importa.

Fluxo proposto:

1. Usuario abre "Ajuda" no app.
2. Ele escolhe: notificacao, cifra, escala, login, disponibilidade, outro.
3. A IA responde com passos simples.
4. Se resolver, ticket fecha sozinho.
5. Se nao resolver, cria ticket real para voce.
6. O ticket precisa chegar com print opcional, logs, tela atual, usuario, igreja e acao.

Categorias que a IA pode resolver:

- Como entrar na igreja.
- Como aceitar/recusar escala.
- Como ativar notificacoes no Android.
- Como baixar setlist offline.
- Como sugerir musica.
- Como mudar tom.
- Como usar modo palco.
- Como mandar print do bug.

Categorias que vao para voce:

- App fechando sozinho.
- Cifra com acorde errado.
- Notificacao nao chegando mesmo com permissao ativa.
- Usuario nao consegue entrar na igreja.
- Dados sumindo.
- Erro de permissao no Firestore.
- API fora do ar.

### Fase 4: seguranca e escala

Objetivo: preparar para mais igrejas sem abrir buracos.

- Ativar App Check enforcement no Firebase e na API Render.
- Revisar regras de `setlists`: dono edita, convidado visualiza ou colabora de forma limitada.
- Trocar rate limit em memoria por Firestore, Redis ou outro store persistente.
- Criar protecao contra abuso de busca.
- Criar protecao contra abuso de notificacao.
- Revisar CORS da API.
- Criar backup/exportacao dos dados importantes.
- Separar ambiente beta e producao.

### Fase 5: Play Store

Itens obrigatorios antes de publicar:

- Criar conta Play Console.
- Gerar Android App Bundle (`.aab`) assinado.
- Configurar Play App Signing.
- Criar politica de privacidade online.
- Preencher Data Safety no Play Console.
- Declarar coleta de dados: email, nome, identificador de usuario, tokens de notificacao, crash logs, dados de uso e conteudo criado pelo usuario.
- Criar opcao de excluir conta e dados.
- Criar conta demo para revisao do Google.
- Preparar screenshots.
- Preparar descricao curta e descricao completa.
- Preparar icone, banner e categoria.
- Testar em pelo menos 12 usuarios por 14 dias se a conta Play Console exigir teste fechado para producao.

Referencias oficiais:

- Requisitos de teste fechado: https://support.google.com/googleplay/android-developer/answer/14151465
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Preparar app para revisao: https://support.google.com/googleplay/android-developer/answer/9859455
- Assinatura do app: https://developer.android.com/studio/publish/app-signing

## Funcionalidades essenciais antes do SaaS publico

Essenciais:

- Feedback/suporte dentro do app.
- Logs com contexto no Crashlytics.
- Politica de privacidade.
- Excluir conta e dados.
- Importacao manual de cifra.
- Edicao de cifra salva.
- Biblioteca oficial do ministerio.
- Melhor separacao entre sugestao e repertorio oficial.
- Melhor onboarding para lider e musico.

Importantes, mas podem esperar:

- Multi-ministerio.
- Substituto sugerido quando alguem recusar.
- Lembrete automatico para quem nao confirmou.
- Anotacoes pessoais na cifra.
- Exportar setlist para PDF/WhatsApp.
- Dashboard web para lider.

Nao fazer agora:

- Chat interno completo.
- Financeiro/ofertas.
- Rede social dentro do app.
- Afinador e metronomo antes da base estar estavel.

## Roadmap musical 2.0

Estas ideias nao sao bloqueadoras do beta, mas sao diferenciais fortes para transformar o Cifra Band em um app musical de referencia.

### 1. Cifra sincronizada com YouTube

Objetivo: ao tocar uma referencia do YouTube, a cifra acompanha a musica automaticamente.

Experiencia desejada:

- Lider adiciona link do YouTube na musica da setlist.
- App abre a cifra com player embutido ou mini-player.
- Conforme o video toca, o app destaca o trecho atual da cifra.
- A cifra rola sozinha para acompanhar a musica.
- Se o usuario arrastar a cifra manualmente, o app pausa o auto-scroll por alguns segundos.
- Quando possivel, exibir marcadores de secao: intro, verso, pre-refrao, refrao, ponte, final.

Implementacao tecnica proposta:

- Usar player YouTube com controle de tempo.
- Ler `currentTime` do player a cada 250ms a 500ms.
- Criar uma camada de `song_timeline` por musica:
  - `songId`
  - `youtubeVideoId`
  - `duration`
  - lista de marcadores `{ startMs, endMs, sectionName, lineStart, lineEnd }`
- No primeiro momento, timeline manual: lider ou admin marca os trechos.
- Depois, criar sugestao inteligente:
  - detectar secoes da cifra pelos headers `[Intro]`, `[Primeira Parte]`, `[Refrão]`.
  - dividir tempo do video proporcionalmente.
  - permitir ajuste fino pelo usuario.
- Futuro avancado: sincronizacao por audio/texto usando reconhecimento de estrutura, mas isso e mais caro e menos previsivel.

Decisao de produto:

- Nao prometer sincronizacao perfeita para todas as musicas.
- Tratar como "Destaque musical" ou "Cifra guiada".
- Para musicas sem timeline, manter rolagem automatica normal por velocidade.

Riscos:

- Nem todo video do YouTube tem a mesma versao que a cifra.
- Ao vivo, medley e ministracao quebram sincronizacao automatica.
- YouTube pode impor limitacoes de background/playback.
- Precisa de UX simples para ajustar marcadores, senao vira recurso pesado demais.

Referencias tecnicas:

- YouTube IFrame Player API: https://developers.google.com/youtube/iframe_api_reference
- YouTube Data API, caso seja necessario buscar metadados de videos: https://developers.google.com/youtube/v3

### 2. Detector de tom por audio

Objetivo: usuario toca/canta um trecho por 5 a 8 segundos e o app sugere o tom mais provavel da musica.

Experiencia desejada:

- Botao "Achar tom" dentro da tela de cifra ou busca.
- Tela com escuta ativa, nota atual em destaque e medidor de confianca.
- App escuta 5 a 8 segundos.
- Ao final, mostra:
  - tom mais provavel: exemplo `B maior`, `G# menor`, `Bbm`.
  - percentual de confianca.
  - top 3 possibilidades.
  - aviso quando a confianca for baixa.
- Botao para aplicar o tom na cifra ou apenas estudar.

Implementacao tecnica proposta:

- Capturar audio do microfone em PCM.
- Rodar pitch detection para detectar frequencia fundamental ao longo do tempo.
- Converter frequencia em nota: C, C#, D, Eb etc.
- Montar histograma das notas detectadas durante 5 a 8 segundos.
- Ignorar ruido, silencio e notas com baixa confianca.
- Inferir tonalidade comparando o histograma com perfis de escalas maiores e menores.
- Mostrar resultado somente se a confianca passar de um limiar minimo.

Bibliotecas/caminhos possiveis:

- `record`: captura audio do microfone em stream no Flutter.
- `pitch_detector_dart`: deteccao de pitch usando algoritmo YIN.
- `fftea`: FFT/STFT para analise de frequencia mais avancada.
- Alternativa Android nativa: plugin baseado em TarsosDSP, mas exige cuidado com manutencao e iOS.

Modelo de algoritmo:

1. Pedir permissao de microfone.
2. Capturar audio mono.
3. A cada janela curta, detectar pitch.
4. Converter Hz para nota MIDI/semitom.
5. Acumular notas em histograma.
6. Testar cada tom maior e menor:
   - notas da escala recebem peso positivo.
   - tonica, dominante e mediante recebem peso maior.
   - notas fora da escala reduzem confianca.
7. Retornar top 3 tons.

Limites honestos:

- Achar tom por audio nao e 100% garantido.
- Intro instrumental, pad, bateria, igreja barulhenta e voz sem instrumento reduzem precisao.
- Funciona melhor com violao/teclado tocando a harmonia da musica.
- Deve ser apresentado como "tom mais provavel", nao como verdade absoluta.

Referencias tecnicas:

- Flutter cookbook para gravar/streamar audio com `record`: https://docs.flutter.dev/cookbook/audio/record
- Pacote `record`: https://pub.dev/packages/record
- Pacote `pitch_detector_dart`: https://pub.dev/packages/pitch_detector_dart
- Documentacao `pitch_detector_dart`: https://pub.dev/documentation/pitch_detector_dart/latest/
- Pacote `fftea`: https://pub.dev/packages/fftea

### 3. Graus e estudo harmonico

Objetivo: transformar a cifra tambem em ferramenta de estudo, mostrando graus dos acordes no tom da musica.

Experiencia desejada:

- Toggle "Graus" na tela de cifra.
- Quando ativo, mostrar acima ou ao lado do acorde:
  - `1`, `2m`, `3m`, `4`, `5`, `6m`, `7dim` conforme o campo harmonico.
- Em tom menor, respeitar campo harmonico menor:
  - menor natural como base.
  - futuramente permitir menor harmonica/melodica para casos especificos.
- Permitir alternar:
  - acordes reais: `C`, `Am`, `F`, `G`.
  - graus: `1`, `6m`, `4`, `5`.
  - ambos.

Implementacao tecnica proposta:

- Usar o `TransposerEngine` atual como base para parse de acordes.
- Criar `HarmonicDegreeEngine` separado.
- Entrada:
  - tom real da musica.
  - acorde parseado.
  - modo maior/menor.
- Saida:
  - grau romano ou numerico.
  - qualidade esperada.
  - diferenca quando o acorde for emprestado/fora do campo.

Decisao de UX:

- Para palco, graus devem ser grandes e limpos.
- Para estudo, pode mostrar detalhes:
  - `4`
  - `subdominante`
  - `fora do campo`
  - `emprestado`

### 4. Diagramas de acordes por instrumento

Objetivo: ao tocar/clicar em um acorde na cifra, abrir como fazer aquele acorde no instrumento escolhido.

Instrumentos prioritarios:

- Violao/guitarra.
- Teclado/piano.
- Baixo depois, como fase futura.

Experiencia desejada:

- Usuario escolhe instrumento padrao no perfil ou na tela de cifra.
- Tocou no acorde `Bbm`, abre bottom sheet com:
  - nome do acorde.
  - variacoes do acorde.
  - diagrama do instrumento atual.
  - botao para trocar instrumento.
- Para violao:
  - pestana, casas, dedos, cordas abafadas e abertas.
- Para teclado:
  - teclas destacadas.
  - inversoes: fundamental, primeira inversao, segunda inversao.
  - mao esquerda/mao direita como evolucao futura.

Implementacao tecnica proposta:

- Criar biblioteca local de acordes em JSON:
  - `assets/chords/guitar.json`
  - `assets/chords/keyboard.json`
- Cada acorde precisa ser normalizado para suportar transposicao:
  - `C`, `Cm`, `C7`, `Cmaj7`, `Csus4`, `Cadd9`, `C/E`.
- Para teclado, muitos acordes podem ser gerados por teoria:
  - maior: 0, 4, 7.
  - menor: 0, 3, 7.
  - diminuto: 0, 3, 6.
  - aumentado: 0, 4, 8.
  - setima dominante: 0, 4, 7, 10.
  - maj7: 0, 4, 7, 11.
  - m7: 0, 3, 7, 10.
  - sus2: 0, 2, 7.
  - sus4: 0, 5, 7.
- Para violao, gerar tudo por teoria e otimizacao e dificil; melhor comecar com base curada dos acordes mais usados.

Decisao de produto:

- Nao mostrar diagramas automaticamente para todos os acordes o tempo todo, porque polui a tela.
- Mostrar ao toque/clique no acorde.
- Na setlist/palco, oferecer uma faixa inferior opcional com os acordes da secao atual.

### 5. Prioridade sugerida

Ordem recomendada:

1. Diagramas de acordes no clique, porque entrega valor rapido e ajuda violonista/tecladista.
2. Graus harmonicos, porque reaproveita o motor de transposicao.
3. Timeline manual de YouTube, porque e diferencial de culto/ensaio.
4. Detector de tom por audio, porque e mais dificil e precisa de muita validacao real.

Definicao de pronto para cada item:

- Diagramas: pelo menos 80 acordes comuns de violao e gerador de acordes de teclado.
- Graus: funcionar para tons maiores e menores, incluindo bemol/sustenido e acordes com baixo.
- YouTube: tocar, pausar, ler tempo atual e destacar secoes marcadas manualmente.
- Detector de tom: 20 testes reais com violao/teclado e taxa aceitavel acima de 80% para top 1, acima de 90% para top 3.

## Estrategia de suporte solo

Como voce vai operar sozinho, o suporte precisa filtrar ruido:

- O usuario sempre envia feedback pelo app.
- A IA tenta resolver duvidas simples.
- Crashlytics captura quedas automaticamente.
- Tickets criticos chegam para voce.
- Tickets de duvida ficam com resposta automatica.
- Problemas de cifra devem virar fila de correcao/importacao manual.

Prioridade dos tickets:

- P0: app nao abre, login quebrado, dados sumiram, escala inacessivel.
- P1: notificacao nao chega, cifra abre vazia, transposicao errada, offline falha.
- P2: botao confuso, fluxo dificil, texto ruim, lentidao.
- P3: sugestao de melhoria.

## Meta do produto

O Cifra Band nao deve tentar ser apenas outro Cifra Club. O posicionamento mais forte e:

> O app de operacao musical para igrejas brasileiras: escala, equipe, disponibilidade, cifra, notificacao e setlist do culto em um so lugar.

O objetivo e fazer o lider parar de depender de WhatsApp, planilha e print de cifra.
