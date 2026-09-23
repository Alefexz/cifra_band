# Inventario tecnico para Data Safety

Inspecao: 21/09/2026. Este documento NAO preenche o formulario e NAO certifica conformidade. Escopo: codigo local Android, chamadas explicitas e comportamentos padrao documentados dos SDKs. Nao houve captura de trafego de um aparelho nem acesso/auditoria das configuracoes do Console (Signals, Ads, BigQuery, retencao, backups). O proprietario precisa confirmar essas configuracoes antes de declarar.

## Dependencias efetivamente resolvidas

`pubspec.lock`: firebase_auth 6.6.1; cloud_firestore 6.9.0; firebase_messaging 16.6.0; firebase_crashlytics 5.3.0; firebase_analytics 12.5.0. Sao versoes FlutterFire, nao as versoes Maven nativas. O grafo nativo e as permissoes finais devem ser lidos no relatorio do AAB, nao inferidos apenas deste lock.

## Por SDK

| SDK | Evidencia no projeto e dados enviados pelo app | Finalidade implementada |
| --- | --- | --- |
| Auth | Login/cadastro e recuperacao por e-mail/senha em onboarding; UID de autenticacao, e-mail, credenciais enviadas ao Firebase Auth. Perfil/nome do usuario tambem existe no Firestore. Nao encontrei login por telefone nem provedor social implementado. A pagina de exclusao usa signInWithPassword diretamente no Google: nao envia a senha ao Render. | Acesso, verificacao de identidade e conta |
| Firestore | `users/{uid}`: nome, e-mail, papeis/instrumentos, igreja, administrador, codigo/amigos, datas; dados privados de push e disponibilidade. Ministerios: nome, administrador, convites; escalas: data/equipe/respostas, repertorio/sugestoes/votos; ensaio: UID, musica, preparo, revisao, nota. Setlists: dono, compartilhamento e musicas. Biblioteca: autoria/edicao por UID, versoes e observacoes. Historico musical conforme documentos das equipes. Suporte descrito abaixo. | Funcionamento, colaboracao, biblioteca, suporte |
| FCM | `push_notification_service.dart`: token FCM, plataforma Android, build e canal direct/play; backend associa UID autenticado. `app_devices`: UID, token, build, timestamps, habilitacao e controle de notificacoes. Compatibilidade com tokens antigos em `users/private/push`. Payloads de notificacao podem conter identificadores de escala/ticket e textos da equipe/suporte. | Entrega de avisos, respostas e atualizacoes |
| Crashlytics | `main.dart`: coleta habilitada explicitamente; erros Flutter, erros fatais de plataforma e zona, stack traces. `setUserIdentifier(user.uid)`, chaves `uid` e `is_admin`. Chaves antigas `user_email` e `church_id` recebem string vazia. `feedback_service.dart`: log com ID de ticket, tipo e severidade. | Diagnostico de falhas |
| Analytics | `app_router.dart`: FirebaseAnalyticsObserver. Nao encontrei chamadas customizadas `logEvent`, `setUserProperty` ou `setUserId`. As paginas CustomTransitionPage deste router nao definem `name`, portanto nao se deve presumir que todas as rotas Flutter geram screen_view. Eventos automaticos nativos/sessoes continuam possiveis. A exclusao chama resetAnalyticsData no aparelho. | Metricas de uso e integracoes dos SDKs |

### Coleta automatica documentada (nao confundir com campos customizados)

Auth usa IP e metadados de agente/app para autenticacao e protecao. Firestore inclui o UID nas requisicoes autenticadas. FCM utiliza identificadores de instalacao e dados tecnicos de entrega; com Analytics pode registrar interacoes. Crashlytics coleta stacks, estado/metadados do aparelho e UUID de instalacao; Installations e Sessions sao dependencias transitivas. A presenca de um SDK nao significa que todos os seus recursos opcionais estejam ativos. [Divulgacao oficial Firebase](https://firebase.google.com/docs/android/play-data-disclosure).

Analytics documenta identificador da instancia, Advertising ID quando disponivel e nao desabilitado, localizacao aproximada derivada de IP mascarado e eventos de ciclo de vida. Nao ha no codigo atual desativacao explicita da coleta publicitaria nem fluxo de consentimento Analytics. Nao foi encontrada funcionalidade de compra/assinatura implementada; eventos de compra nao devem ser inventados. Signals, integracao Ads e compartilhamento dependem tambem do Console, que nao foi auditado. [Divulgacao oficial Analytics](https://support.google.com/analytics/answer/11582702).

## Igreja/e-mail e identificadores: verificacao separada

Verificacao adicional de 22/09/2026 no AAB real: estao presentes `com.google.android.gms.permission.AD_ID`, `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` e `android.permission.ACCESS_ADSERVICES_AD_ID`. Portanto a coleta publicitaria nao deve ser declarada como desativada apenas porque o app nao mostra anuncios. Isso nao prova que um Advertising ID tenha sido efetivamente enviado em uma sessao especifica; depende de disponibilidade/consentimento/configuracao. Nenhuma dessas opcoes foi alterada silenciosamente.

Campos adicionais confirmados: disponibilidade guarda `date`, `reason` e `created_at`; o motivo e texto livre e pode conter informacao sensivel. Historico guarda `title`, `artist`, `originalKey`, `shapeKey`, `capo`, `referenceUrl`, `rehearsalNotes`, `bpm`, `content`, `url`, `played_at`. Ensaio usa `uid`, `songKey`, `title`, `artist`, `rehearsed`, `note`, `updated_at`, `preparation`, `arrangementRevision`. Metadados de conta excluida tambem incluem um marcador local por UID que bloqueia gravacoes de referencias antigas; nao contem notas/cifras, mas ainda sao identificadores locais.

| Destino | Resultado da leitura do codigo |
| --- | --- |
| Chaves customizadas Crashlytics | E-mail/igreja limpos, mas UID, is_admin e ID do ticket permanecem correlacionaveis. Nao e telemetria anonima. |
| Analytics customizado | Nenhum envio explicito de e-mail/igreja/UID encontrado. Nao afirmar ausencia de todo dado pessoal: identificadores automaticos e opcoes do Console sao distintos. |
| Diagnostico local anexado ao suporte | `AppDiagnosticsService` mascara chaves contendo email/password/token/authorization/secret. UID e church_id NAO sao mascarados. Mensagens/erros livres e respostas HTTP podem carregar dados embutidos; a mascara por nome de chave nao garante limpeza desses textos. |
| Feedback HTTP / Firestore | `feedback_service.dart` manda nome, church_id e is_admin; o servidor acrescenta UID/e-mail da identidade verificada. Tambem guarda IP/user-agent da requisicao, versao/build/pacote, aparelho e ate 80 entradas de log. Igreja e e-mail continuam aqui, apesar da limpeza do Crashlytics. |
| Notificacoes | Textos e IDs compartilhados pelo fluxo de equipe/suporte; revisar exibicao na tela bloqueada. Token e UID ficam no banco. |

O vinculo a uma igreja pode revelar crenca religiosa. E um dado que exige revisao especifica na politica e no formulario, nao apenas a categoria generica "nome". A decisao de necessidade, consentimento/base legal e classificacao final e do responsavel com orientacao juridica. Nao removi campos funcionais nem escolhi a politica de conteudo nesta tarefa.

## Fora dos SDKs Firebase

- Render recebe autenticacao Bearer nos endpoints protegidos, consultas de artista/musica, tickets e diagnostico. O servidor consulta provedores de catalogo/cifras. Provedores/CDNs de capas recebem requisicoes e dados tecnicos de rede; nao concluir que somente Firebase recebe dados.
- Canal direto consulta metadados de versao e baixa APK do GitHub; canal Play usa Play Core. Os comportamentos dos canais diferem e o formulario deve descrever o artefato Play.
- SharedPreferences guarda favoritos, anotacoes e downloads por UID; Firestore mantem cache em disco. Esses dados locais nao equivalem por si so a coleta fora do aparelho.
- `device_info_plus` fornece os campos enviados no suporte; nao e uma plataforma de analytics independente neste projeto.
- A exclusao cria um protocolo aleatorio e um bloqueio por UID. Apos concluir, remove UID do protocolo; o bloqueio tecnico por UID e o protocolo expiram em 30 dias, removidos pelo worker. Erros operacionais do worker registram apenas hash do protocolo/codigo.

## Limites da exclusao e retencao

A rotina remove dados operacionais mapeados no Firestore e a conta Auth, revoga sessao e remove tokens. O app solicitante apaga dados locais e cache Firestore, reiniciando o processo antes de voltar ao uso. Isso NAO apaga retroativamente relatorios Crashlytics/Analytics, logs da infraestrutura, backups ou copias ja baixadas por outros aparelhos/usuarios. `resetAnalyticsData` nao e uma chamada de exclusao dos eventos ja enviados ao servidor. [Politicas/retencoes Firebase](https://firebase.google.com/support/privacy).

Antes da publicacao, verificar retencoes efetivas e mecanismos administrativos dos provedores, documentar excecoes/prazos, e manter um procedimento operacional para pedidos relativos a telemetria/backups. Nao declarar "todos os dados de todos os provedores apagados imediatamente".

## Evidencias pendentes do proprietario

1. Confirmar Console Analytics: Signals, Ads, audiencias, compartilhamento e BigQuery.
2. Confirmar retencao/backups Firestore, logs Render/Google e acesso do suporte.
3. Decidir coleta publicitaria/consentimento; conferir AD_ID no manifesto final.
4. Aprovar e publicar politica de privacidade com a lista real de destinatarios, finalidades, retencoes e canal de direitos.
5. Configurar/publicar a pagina de exclusao e executar teste com conta descartavel em ambiente de homologacao.
6. Preencher pessoalmente Data Safety considerando conteudo/servicos finalmente escolhidos. Esta tarefa nao resolveu direitos sobre letras, cifras, capas ou redistribuicao.
