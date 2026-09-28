# Cifra Band 1.6.2: verificacao funcional e inventario

Data: 27/09/2026. Beta direto Android: 1.6.2+30. Repositorios: `cifra_band` e `cifraband-api` (em `functions/`).

## Parecer para o culto

O fluxo de consulta foi melhorado, mas **nao e seguro afirmar que toda musica ou todo medley publicado sera encontrado**. Sites externos podem bloquear consultas, mudar HTML, publicar cifra parcial ou ter outra versao/tom. Para repertorio critico, confira cada cifra antes do culto e baixe a setlist para uso offline. Uma cifra so de introducao/tablatura nao deve ser tratada como letra completa.

## O que foi verificado nesta entrega

| Area | Evidencia | Resultado e limite |
| --- | --- | --- |
| APK direto | `aapt`, `apksigner`, SHA-256, HEAD no asset | 1.6.2+30, target SDK 36, mesma assinatura do beta existente; 68.183.086 bytes. |
| Manifesto | `/app-version` em Render | Versao 1.6.2+30, URL, tamanho e hash publicados. |
| Flutter | `flutter test --no-pub` | 136 testes passaram; 1 teste Play-only ignorado. Nao equivale a teste em todos os aparelhos. |
| Backend | testes Node selecionados | 38 passaram apos a correcao do YouTube. |
| Firestore | Auth/Firestore Emulator | Bateria passou. Nao comprova estado ou indices do Firestore de producao. |
| Cifras | consultas reais locais por artista/titulo | Encontradas com letra e acordes: medleys Midian Lima, Banda Som e Louvor, Attos2 Worship e Corinhos Evangelicos; tambem Ah Jesus, Bondade de Deus, Galileu, A Casa E Sua, Porque Ele Vive e Nao Acabou. |
| Medley parcial | Ruja o Leao / Talita Cumi | Nao entregou so a primeira faixa: respondeu indisponibilidade quando nao confirmou a cifra composta. |
| YouTube | busca publica + verificacao de metadados | Videos encontrados para Midian Lima, Attos2 Worship e Banda Som e Louvor; artista errado e cover rejeitados nos testes. |
| Download do app | testes de intervalo, tamanho e hash | Retomada de download parcial em novo cliente; APK sempre validado antes da instalacao. A velocidade real ainda depende do GitHub e da rede. |

### Caminho da cifra

1. O catalogo mostra musica e artista; o clique consulta cache local e depois `GET /searchSong` com token Firebase.
2. O Render confere cache em memoria e `global_cifras` no Firestore. Sem entrada valida, consulta provedores externos por titulo/artista.
3. O conteudo so deve ser entregue se tiver identidade compativel e letra com acordes suficientes. Uma tablatura ou trecho isolado nao vale como cifra completa.
4. O app abre a tela de cifra, onde usuario pode ajustar tom/capo, estudar acordes, salvar em setlist e baixar repertorio offline.
5. O video da sugestao e resolvido separadamente; falha do YouTube nao deve segurar a cifra.

Consultas locais observadas: medley Midian Lima ~10 s, Banda Som e Louvor ~20 s, Attos2 Worship ~8 s e Corinhos Evangelicos ~18 s, sem cache. Sao amostras, nao um SLA. O Render Free pode acrescentar tempo de despertar; provedores externos podem responder 403. Sem uma versao completa confirmada, o app deve mostrar indisponibilidade, nao inventar letra/tom.

### Pontos de controle para hoje

| Verificacao no aparelho | Resultado esperado |
| --- | --- |
| Abrir app com internet | Aparece oferta 1.6.2+30 para quem usa build anterior; download concluido permite instalar. |
| Pesquisar `Medley - Corinhos de Fogo` / `Midian Lima` | Cifra com letra e acordes; YouTube na sugestao abre video verificado. |
| Pesquisar `Medley Pentecostal` / `Attos2 Worship` | Cifra completa e video, mas comparar tom com o ensaio. |
| Baixar setlist e cortar internet | Cifras aprovadas devem abrir offline; testar **antes** da reuniao. |
| Falha de provedor | Mensagem clara e botao de repetir; nao confundir bloqueio externo com inexistencia da musica. |

## Funcionalidades e arquivos-chave

| Funcionalidade | Fluxo atual | Arquivos centrais | Risco/limite |
| --- | --- | --- | --- |
| Login e conta | Firebase Auth, perfil e exclusao | `lib/main.dart`, `lib/features/home/presentation/screens/onboarding_screen.dart`, `lib/features/home/presentation/screens/account_deletion_screen.dart`, `functions/lib/account-deletion.js` | Requer validar fluxo real em aparelhos e politicas da loja. |
| Ministerio e papeis | Convites, membros, dono separado de admin local | `lib/features/home/presentation/screens/create_ministry_screen.dart`, `lib/core/services/app_owner_service.dart`, `functions/lib/member-actions.js`, `firestore.rules` | Auditoria de autorizacao continua necessaria a cada novo endpoint. |
| Escalas e disponibilidade | Cultos, equipe, confirmacao, indisponibilidades | `lib/features/home/presentation/screens/schedules_screen.dart`, `event_detail_screen.dart`, `availability_screen.dart` | Mudancas em Firestore podem depender de indices de producao. |
| Repertorio do culto | Sugestao, votacao, aprovacao, preparacao | `event_detail_screen.dart`, `rehearsal_center_screen.dart`, `lib/core/services/rehearsal_preparation.dart`, `functions/lib/member-actions.js` | Referencia externa nao significa que a cifra completa foi conferida pelo musico. |
| Busca de musicas | Pesquisa por musica/artista e ranking | `lib/features/home/data/music_search_service.dart`, `music_search_ranking.dart`, `functions/lib/catalog-search.js` | Catalogos externos podem variar; nao ha promessa de 99% universal. |
| Busca e leitura de cifras | Cache, fonte externa, validacao, transposicao | `lib/features/songs/data/datasources/song_scraper_datasource.dart`, `cifra_screen.dart`, `functions/server.js`, `functions/lib/chord-content.js` | Qualidade/tom de terceiros nao sao garantidos; limite de provedores externos. |
| Medleys | Nome catalogado preservado; composicao parcial recusada | `functions/lib/song-title.js`, `functions/server.js` | Titulos nao padronizados ainda podem falhar; precisam de revisao humana. |
| YouTube na sugestao | Busca e confirmacao de video; Spotify oculto | `song_listening_sheet.dart`, `functions/lib/song-links.js` | Video correto depende de metadados publicos do YouTube. |
| Setlists e offline | Criacao, musicas, download, retencao | `lib/features/setlist/`, `lib/core/services/offline_setlist_service.dart`, `firestore.rules` | Testes automatizados nao substituem ensaio offline real com setlist da igreja. |
| Biblioteca oficial | Cifra criada/editada pelo ministerio | `official_library_screen.dart`, `official_song_editor_screen.dart`, `official_library_service.dart` | Conteudo publicado por usuarios exige moderacao e direitos. |
| Teoria e acordes | Diagramas, teclado, graus, capo | `lib/core/services/chord_study_service.dart`, `lib/core/music/chord_shape_catalog.dart`, `lib/features/songs/presentation/widgets/chord_diagrams/` | Diagramas e tom precisam conferencia musical; versoes de fonte podem divergir. |
| Suporte | Ticket, resposta, diagnostico e painel | `support_ticket_service.dart`, `support-panel/`, `functions/server.js` | Logs podem conter dados sensiveis; controlar acesso e retencao. |
| Push | Atualizacao, escalas e suporte | `push_notification_service.dart`, `functions/lib/update-push.js` | Entrega FCM nao e garantida nem substitui consulta ao abrir o app. |
| Atualizacao direta | Manifesto Render, download GitHub, instalador Android | `app_update_direct.dart`, `apk_downloader.dart`, `android/app/src/direct/` | 1.6.2 retoma transferencias futuras; quem ainda usa 1.6.1 baixa o APK atual inteiro. |
| Edicao Play | Atualizacao nativa da loja, sem instalador direto | `app_update_play.dart`, `android/app/src/play/`, `android/app/build.gradle.kts` | Nao publicada; direitos de cifras e requisitos da Play ainda bloqueiam lancamento. |

## Pendencias honestas

1. Validar no celular/tablet da igreja a abertura de uma cifra, o medley, o link YouTube e uma setlist offline completa. Os testes daqui nao controlam a conta e a conectividade desses aparelhos.
2. Medir disponibilidade e latencia do Render e dos provedores em producao por varias horas/dias; uma amostra local nao comprova cobertura total.
3. Confirmar musica e tom da versao escolhida antes do culto. Um mesmo louvor pode ter gravacoes/arranjos em tons diferentes.
4. Nao publicar esta edicao de cifras de terceiros na Play sem resolver licencas, moderacao e declaracoes de privacidade. O APK direto e beta de igreja, nao uma aprovacao juridica.

## Inventario completo dos arquivos versionados

As listas abaixo sao um inventario de **todos os caminhos versionados** nos dois repositorios, nao uma alegacao de que cada arquivo teve teste funcional individual. Arquivos gerados/locais ignorados pelo Git, como chaves, configuracoes privadas, `build/` e `node_modules/`, nao constam. Arquivos de `docs/`, `test/` e recursos binarios sao distinguidos por caminho.

### Aplicativo (`249` arquivos)

| Arquivo | Responsabilidade pelo nome/localizacao |
| --- | --- |
| `.gitignore` | Exclusoes do Git |
| `.metadata` | Metadados do projeto Flutter |
| `README.md` | Projeto: README |
| `SECURITY.md` | Projeto: SECURITY |
| `analysis_options.yaml` | Configuracao/dependencias |
| `android/.gitignore` | Configuracao/recurso Android |
| `android/app/build.gradle.kts` | Configuracao/recurso Android |
| `android/app/src/debug/AndroidManifest.xml` | Configuracao/recurso Android |
| `android/app/src/direct/AndroidManifest.xml` | Configuracao/recurso Android |
| `android/app/src/direct/kotlin/br/com/cifraband/cifra_band/MainActivity.kt` | Configuracao/recurso Android |
| `android/app/src/main/AndroidManifest.xml` | Configuracao/recurso Android |
| `android/app/src/main/res/drawable-v21/launch_background.xml` | Configuracao/recurso Android |
| `android/app/src/main/res/drawable/launch_background.xml` | Configuracao/recurso Android |
| `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | Configuracao/recurso Android |
| `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | Configuracao/recurso Android |
| `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | Configuracao/recurso Android |
| `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | Configuracao/recurso Android |
| `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | Configuracao/recurso Android |
| `android/app/src/main/res/values-night/styles.xml` | Configuracao/recurso Android |
| `android/app/src/main/res/values/strings.xml` | Configuracao/recurso Android |
| `android/app/src/main/res/values/styles.xml` | Configuracao/recurso Android |
| `android/app/src/main/res/xml/file_paths.xml` | Configuracao/recurso Android |
| `android/app/src/play/AndroidManifest.xml` | Configuracao/recurso Android |
| `android/app/src/play/kotlin/br/com/cifraband/cifra_band/MainActivity.kt` | Configuracao/recurso Android |
| `android/app/src/profile/AndroidManifest.xml` | Configuracao/recurso Android |
| `android/build.gradle.kts` | Configuracao/recurso Android |
| `android/gradle.properties` | Configuracao/recurso Android |
| `android/gradle/wrapper/gradle-wrapper.properties` | Configuracao/recurso Android |
| `android/settings.gradle.kts` | Configuracao/recurso Android |
| `assets/images/logo.png` | Recurso visual |
| `assets/images/logo_symbol_only.png` | Recurso visual |
| `docs/ACCOUNT_DELETION.md` | Documento: ACCOUNT DELETION |
| `docs/ATUALIZACAO_VERSOES_ANTIGAS.md` | Documento: ATUALIZACAO VERSOES ANTIGAS |
| `docs/AUDITORIA_CIFRAS_BANCO_1_5_3.md` | Documento: AUDITORIA CIFRAS BANCO 1 5 3 |
| `docs/AUDITORIA_GERAL_2026_09_12.md` | Documento: AUDITORIA GERAL 2026 09 12 |
| `docs/AUDITORIA_TECNICA_2026_09_15.md` | Documento: AUDITORIA TECNICA 2026 09 15 |
| `docs/CORRECAO_DIAGRAMAS_ACORDES.md` | Documento: CORRECAO DIAGRAMAS ACORDES |
| `docs/DEPLOY_1_5_6.md` | Documento: DEPLOY 1 5 6 |
| `docs/DEPLOY_1_5_7.md` | Documento: DEPLOY 1 5 7 |
| `docs/DEPLOY_1_5_8.md` | Documento: DEPLOY 1 5 8 |
| `docs/DEPLOY_1_5_9.md` | Documento: DEPLOY 1 5 9 |
| `docs/DEPLOY_1_6_0.md` | Documento: DEPLOY 1 6 0 |
| `docs/ESTABILIZACAO_ETAPA_1.md` | Documento: ESTABILIZACAO ETAPA 1 |
| `docs/HOTFIX_SETLISTS_2026_09_13.md` | Documento: HOTFIX SETLISTS 2026 09 13 |
| `docs/MELHORIA_PESQUISA.md` | Documento: MELHORIA PESQUISA |
| `docs/PLAY_BLOQUEADORES_TECNICOS_2026_09_22.md` | Documento: PLAY BLOQUEADORES TECNICOS 2026 09 22 |
| `docs/PLAY_DATA_SAFETY.md` | Documento: PLAY DATA SAFETY |
| `docs/PLAY_SIGNING.md` | Documento: PLAY SIGNING |
| `docs/PRONTIDAO_PLAY_STORE_2026_09_21.md` | Documento: PRONTIDAO PLAY STORE 2026 09 21 |
| `docs/PUSH_ATUALIZACOES.md` | Documento: PUSH ATUALIZACOES |
| `docs/RELATORIO_FUNCIONAL_1_6_2.md` | Documento: RELATORIO FUNCIONAL 1 6 2 |
| `docs/RELEASE_1_5_3.md` | Documento: RELEASE 1 5 3 |
| `docs/RELEASE_1_5_4.md` | Documento: RELEASE 1 5 4 |
| `docs/RELEASE_1_5_5.md` | Documento: RELEASE 1 5 5 |
| `docs/RELEASE_1_5_6.md` | Documento: RELEASE 1 5 6 |
| `docs/RELEASE_1_5_7.md` | Documento: RELEASE 1 5 7 |
| `docs/RELEASE_1_5_8.md` | Documento: RELEASE 1 5 8 |
| `docs/RELEASE_1_5_9.md` | Documento: RELEASE 1 5 9 |
| `docs/RELEASE_1_6_0.md` | Documento: RELEASE 1 6 0 |
| `docs/SUGESTOES_SEM_CIFRA.md` | Documento: SUGESTOES SEM CIFRA |
| `docs/TESTE_50_MUSICAS_1_5_5.md` | Documento: TESTE 50 MUSICAS 1 5 5 |
| `docs/plano-publicacao-cifra-band.md` | Documento: plano publicacao cifra band |
| `firebase.emulators.json` | Configuracao/dependencias |
| `firestore.indexes.json` | Configuracao/dependencias |
| `firestore.rules` | Projeto: firestore |
| `ios/.gitignore` | Configuracao/recurso iOS |
| `ios/Flutter/AppFrameworkInfo.plist` | Configuracao/recurso iOS |
| `ios/Flutter/Debug.xcconfig` | Configuracao/recurso iOS |
| `ios/Flutter/Release.xcconfig` | Configuracao/recurso iOS |
| `ios/Runner.xcodeproj/project.pbxproj` | Configuracao/recurso iOS |
| `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | Configuracao/recurso iOS |
| `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | Configuracao/recurso iOS |
| `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Configuracao/recurso iOS |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | Configuracao/recurso iOS |
| `ios/Runner.xcworkspace/contents.xcworkspacedata` | Configuracao/recurso iOS |
| `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | Configuracao/recurso iOS |
| `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Configuracao/recurso iOS |
| `ios/Runner/AppDelegate.swift` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png` | Configuracao/recurso iOS |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | Configuracao/recurso iOS |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Configuracao/recurso iOS |
| `ios/Runner/Base.lproj/Main.storyboard` | Configuracao/recurso iOS |
| `ios/Runner/Info.plist` | Configuracao/recurso iOS |
| `ios/Runner/Runner-Bridging-Header.h` | Configuracao/recurso iOS |
| `ios/Runner/SceneDelegate.swift` | Configuracao/recurso iOS |
| `ios/RunnerTests/RunnerTests.swift` | Configuracao/recurso iOS |
| `lib/config/routes/app_router.dart` | Logica: app router |
| `lib/core/database/database_helper.dart` | Logica: database helper |
| `lib/core/music/chord_shape_catalog.dart` | Logica: chord shape catalog |
| `lib/core/services/account_deletion_service.dart` | Servico: account deletion service |
| `lib/core/services/account_local_data_service.dart` | Servico: account local data service |
| `lib/core/services/api_notification.dart` | Servico: api notification |
| `lib/core/services/apk_artifact.dart` | Servico: apk artifact |
| `lib/core/services/apk_downloader.dart` | Servico: apk downloader |
| `lib/core/services/app_diagnostics_service.dart` | Servico: app diagnostics service |
| `lib/core/services/app_owner_service.dart` | Servico: app owner service |
| `lib/core/services/app_update_direct.dart` | Servico: app update direct |
| `lib/core/services/app_update_play.dart` | Servico: app update play |
| `lib/core/services/app_update_service.dart` | Servico: app update service |
| `lib/core/services/availability_service.dart` | Servico: availability service |
| `lib/core/services/backend_warmup_service.dart` | Servico: backend warmup service |
| `lib/core/services/chord_study_service.dart` | Servico: chord study service |
| `lib/core/services/feedback_service.dart` | Servico: feedback service |
| `lib/core/services/member_actions_service.dart` | Servico: member actions service |
| `lib/core/services/official_library_service.dart` | Servico: official library service |
| `lib/core/services/offline_setlist_service.dart` | Servico: offline setlist service |
| `lib/core/services/personal_setlist_service.dart` | Servico: personal setlist service |
| `lib/core/services/played_history_service.dart` | Servico: played history service |
| `lib/core/services/push_notification_service.dart` | Servico: push notification service |
| `lib/core/services/rehearsal_preparation.dart` | Servico: rehearsal preparation |
| `lib/core/services/rehearsal_service.dart` | Servico: rehearsal service |
| `lib/core/services/schedule_reminder_service.dart` | Servico: schedule reminder service |
| `lib/core/services/setlist_contacts_service.dart` | Servico: setlist contacts service |
| `lib/core/services/song_annotation_service.dart` | Servico: song annotation service |
| `lib/core/services/support_ticket_service.dart` | Servico: support ticket service |
| `lib/core/theme/app_theme.dart` | Logica: app theme |
| `lib/features/home/data/music_search_service.dart` | Logica: music search service |
| `lib/features/home/domain/music_search_ranking.dart` | Logica: music search ranking |
| `lib/features/home/presentation/providers/home_providers.dart` | Estado/controlador: home providers |
| `lib/features/home/presentation/screens/account_deletion_screen.dart` | Tela: account deletion screen |
| `lib/features/home/presentation/screens/add_friend_screen.dart` | Tela: add friend screen |
| `lib/features/home/presentation/screens/availability_screen.dart` | Tela: availability screen |
| `lib/features/home/presentation/screens/create_ministry_screen.dart` | Tela: create ministry screen |
| `lib/features/home/presentation/screens/cult_setlist_player_screen.dart` | Tela: cult setlist player screen |
| `lib/features/home/presentation/screens/event_detail_screen.dart` | Tela: event detail screen |
| `lib/features/home/presentation/screens/feedback_screen.dart` | Tela: feedback screen |
| `lib/features/home/presentation/screens/home_screen.dart` | Tela: home screen |
| `lib/features/home/presentation/screens/my_support_screen.dart` | Tela: my support screen |
| `lib/features/home/presentation/screens/onboarding_screen.dart` | Tela: onboarding screen |
| `lib/features/home/presentation/screens/profile_screen.dart` | Tela: profile screen |
| `lib/features/home/presentation/screens/rehearsal_center_screen.dart` | Tela: rehearsal center screen |
| `lib/features/home/presentation/screens/schedules_screen.dart` | Tela: schedules screen |
| `lib/features/home/presentation/screens/search_screen.dart` | Tela: search screen |
| `lib/features/home/presentation/screens/support_center_screen.dart` | Tela: support center screen |
| `lib/features/home/presentation/widgets/logo_loader.dart` | Componente visual: logo loader |
| `lib/features/home/presentation/widgets/rehearsal_panel.dart` | Componente visual: rehearsal panel |
| `lib/features/home/presentation/widgets/song_lookup_dialog.dart` | Componente visual: song lookup dialog |
| `lib/features/setlist/data/models/setlist_model.dart` | Modelo de dados: setlist model |
| `lib/features/setlist/data/repositories/setlist_repository_impl.dart` | Repositorio: setlist repository impl |
| `lib/features/setlist/domain/entities/setlist_entity.dart` | Modelo de dados: setlist entity |
| `lib/features/setlist/domain/repositories/setlist_repository.dart` | Repositorio: setlist repository |
| `lib/features/setlist/presentation/controllers/setlist_controller.dart` | Estado/controlador: setlist controller |
| `lib/features/setlist/presentation/providers/setlist_providers.dart` | Estado/controlador: setlist providers |
| `lib/features/setlist/presentation/screens/favorite_songs_screen.dart` | Tela: favorite songs screen |
| `lib/features/setlist/presentation/screens/offline_setlists_screen.dart` | Tela: offline setlists screen |
| `lib/features/setlist/presentation/screens/played_history_screen.dart` | Tela: played history screen |
| `lib/features/setlist/presentation/screens/setlist_detail_screen.dart` | Tela: setlist detail screen |
| `lib/features/setlist/presentation/screens/setlist_screen.dart` | Tela: setlist screen |
| `lib/features/setlist/presentation/widgets/add_to_setlist_sheet.dart` | Componente visual: add to setlist sheet |
| `lib/features/setlist/presentation/widgets/create_setlist_modal.dart` | Componente visual: create setlist modal |
| `lib/features/setlist/presentation/widgets/setlist_card.dart` | Componente visual: setlist card |
| `lib/features/songs/data/datasources/song_scraper_datasource.dart` | Fonte de dados: song scraper datasource |
| `lib/features/songs/data/models/cifra_search_model.dart` | Modelo de dados: cifra search model |
| `lib/features/songs/data/models/song_model.dart` | Modelo de dados: song model |
| `lib/features/songs/data/repositories/song_repository_impl.dart` | Repositorio: song repository impl |
| `lib/features/songs/domain/entities/song_destination.dart` | Modelo de dados: song destination |
| `lib/features/songs/domain/entities/song_entity.dart` | Modelo de dados: song entity |
| `lib/features/songs/domain/repositories/song_repository.dart` | Repositorio: song repository |
| `lib/features/songs/domain/song_arrangement.dart` | Logica: song arrangement |
| `lib/features/songs/domain/song_content_quality.dart` | Logica: song content quality |
| `lib/features/songs/domain/song_listening.dart` | Logica: song listening |
| `lib/features/songs/domain/transposer_engine.dart` | Logica: transposer engine |
| `lib/features/songs/presentation/providers/song_providers.dart` | Estado/controlador: song providers |
| `lib/features/songs/presentation/screens/add_song_screen.dart` | Tela: add song screen |
| `lib/features/songs/presentation/screens/cifra_screen.dart` | Tela: cifra screen |
| `lib/features/songs/presentation/screens/official_library_screen.dart` | Tela: official library screen |
| `lib/features/songs/presentation/screens/official_song_editor_screen.dart` | Tela: official song editor screen |
| `lib/features/songs/presentation/widgets/chord_diagrams/guitar_chord_diagram.dart` | Componente visual: guitar chord diagram |
| `lib/features/songs/presentation/widgets/chord_diagrams/keyboard_chord_diagram.dart` | Componente visual: keyboard chord diagram |
| `lib/features/songs/presentation/widgets/song_listening_sheet.dart` | Componente visual: song listening sheet |
| `lib/features/songs/presentation/widgets/song_suggestion_sheet.dart` | Componente visual: song suggestion sheet |
| `lib/main.dart` | Logica: main |
| `pubspec.lock` | Configuracao/dependencias |
| `pubspec.yaml` | Configuracao/dependencias |
| `releases/cifra-band-1.3.0-build-15.apk` | APK historico |
| `releases/cifra-band-1.4.0-build-16.apk` | APK historico |
| `releases/cifra-band-1.5.0-build-18.apk` | APK historico |
| `releases/cifra-band-1.5.1-build-19.apk` | APK historico |
| `releases/cifra-band-1.5.2-build-20.apk` | APK historico |
| `support-panel/README.md` | Painel/pagina web |
| `support-panel/config.example.js` | Painel/pagina web |
| `support-panel/index.html` | Painel/pagina web |
| `test/account_deletion_local_test.dart` | Teste: account deletion local test |
| `test/account_deletion_screen_test.dart` | Teste: account deletion screen test |
| `test/account_local_data_test.dart` | Teste: account local data test |
| `test/apk_artifact_test.dart` | Teste: apk artifact test |
| `test/apk_downloader_test.dart` | Teste: apk downloader test |
| `test/capo_chord_detail_test.dart` | Teste: capo chord detail test |
| `test/chord_diagrams_test.dart` | Teste: chord diagrams test |
| `test/firestore/account-deletion.test.cjs` | Teste: account deletion.test |
| `test/firestore/package-lock.json` | Teste: package lock |
| `test/firestore/package.json` | Teste: package |
| `test/firestore/rules.test.cjs` | Teste: rules.test |
| `test/firestore/update-push.test.cjs` | Teste: update push.test |
| `test/music_search_hybrid_test.dart` | Teste: music search hybrid test |
| `test/music_search_screen_test.dart` | Teste: music search screen test |
| `test/music_search_test.dart` | Teste: music search test |
| `test/offline_download_retention_test.dart` | Teste: offline download retention test |
| `test/personal_setlist_test.dart` | Teste: personal setlist test |
| `test/play_update_test.dart` | Teste: play update test |
| `test/rehearsal_preparation_test.dart` | Teste: rehearsal preparation test |
| `test/release_156_test.dart` | Teste: release 156 test |
| `test/required_update_refresh_test.dart` | Teste: required update refresh test |
| `test/setlist_contacts_test.dart` | Teste: setlist contacts test |
| `test/setlist_controller_test.dart` | Teste: setlist controller test |
| `test/song_cache_warmup_test.dart` | Teste: song cache warmup test |
| `test/song_integrity_test.dart` | Teste: song integrity test |
| `test/song_links_panel_test.dart` | Teste: song links panel test |
| `test/song_listening_test.dart` | Teste: song listening test |
| `test/song_lookup_dialog_test.dart` | Teste: song lookup dialog test |
| `test/widget_test.dart` | Teste: widget test |
| `tool/audit_chord_notes.dart` | Projeto: audit chord notes |
| `tool/audit_cifra_sources.cjs` | Projeto: audit cifra sources |
| `tool/audit_firestore_risks.cjs` | Projeto: audit firestore risks |
| `tool/audit_response_times.dart` | Projeto: audit response times |
| `tool/benchmark_music_search.dart` | Projeto: benchmark music search |
| `tool/check_music_search.dart` | Projeto: check music search |
| `tool/check_play_readiness.ps1` | Projeto: check play readiness |
| `tool/check_stabilization.ps1` | Projeto: check stabilization |
| `tool/inspect_native_artifact.cjs` | Projeto: inspect native artifact |
| `tool/inspect_play_aab.ps1` | Projeto: inspect play aab |
| `tool/migrate_release_156.cjs` | Projeto: migrate release 156 |
| `tool/test_account_deletion_page.cjs` | Projeto: test account deletion page |
| `tool/verify_search_156.dart` | Projeto: verify search 156 |

### Backend (`37` arquivos)

| Arquivo | Responsabilidade pelo nome/localizacao |
| --- | --- |
| `functions/.env.example` | Exemplo de configuracao do servidor, sem secrets reais |
| `functions/.eslintrc.js` | Backend: .eslintrc |
| `functions/.gitignore` | Exclusoes do Git no backend |
| `functions/index.js` | Backend: index |
| `functions/lib/account-deletion.js` | Logica: account deletion |
| `functions/lib/catalog-search.js` | Logica: catalog search |
| `functions/lib/chord-content.js` | Logica: chord content |
| `functions/lib/firebase-auth.js` | Logica: firebase auth |
| `functions/lib/index.js` | Logica: index |
| `functions/lib/index.js.map` | Logica: index.js |
| `functions/lib/member-actions.js` | Logica: member actions |
| `functions/lib/screens/home_screen.dart` | Tela: home screen |
| `functions/lib/services/api_service.dart` | Servico: api service |
| `functions/lib/song-links.js` | Logica: song links |
| `functions/lib/song-title.js` | Logica: song title |
| `functions/lib/source-diagnostics.js` | Logica: source diagnostics |
| `functions/lib/update-push.js` | Logica: update push |
| `functions/lib/youtube-background.js` | Logica: youtube background |
| `functions/package-lock.json` | Configuracao/dependencias |
| `functions/package.json` | Configuracao/dependencias |
| `functions/public/account-deletion.css` | Painel/pagina web |
| `functions/public/account-deletion.html` | Painel/pagina web |
| `functions/public/account-deletion.js` | Painel/pagina web |
| `functions/server.js` | Backend: server |
| `functions/src/index.ts` | Backend: index |
| `functions/test-account-deletion.js` | Teste: test account deletion |
| `functions/test-catalog-search.js` | Teste: test catalog search |
| `functions/test-content.js` | Teste: test content |
| `functions/test-distribution.js` | Teste: test distribution |
| `functions/test-member-actions.js` | Teste: test member actions |
| `functions/test-search.js` | Teste: test search |
| `functions/test-song-links.js` | Teste: test song links |
| `functions/test-top-gospel-150.js` | Teste: test top gospel 150 |
| `functions/test-update-version.js` | Teste: test update version |
| `functions/test-youtube-background.js` | Teste: test youtube background |
| `functions/tsconfig.dev.json` | Configuracao/dependencias |
| `functions/tsconfig.json` | Configuracao/dependencias |
