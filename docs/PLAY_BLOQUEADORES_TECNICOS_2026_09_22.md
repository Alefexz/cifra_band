# Bloqueadores tecnicos Play: resultado local

Concluido em 22/09/2026. Nenhum push/deploy, release GitHub, alteracao de variaveis Render, publicacao Play ou geracao de chave. A versao continua 1.5.9+27: os arquivos abaixo sao de inspecao, NAO uma nova atualizacao para usuarios. Licenciamento/edicao de conteudo nao foram decididos nem alterados.

## Situacao por item

| Item | Entregue | Pendente antes de publicar |
| --- | --- | --- |
| 1. Canais | Flavors direct/play, manifestos e MainActivity separados; selecao compile-time do updater. Play Core 2.1.0; Play sem instalador externo. Push de APK exclui dispositivos registrados como play. Grafo Direct sem tarefas Play. | Testar atualizacao real em pista interna Play; clientes precisam registrar canal no backend implantado. |
| 2. Assinatura | Play exige arquivo de chave externo. Release normal falha sem chave. Excecao explicita gera AAB SEM assinatura so para inspecao. Certificado Direct conferido e preservado. | Proprietario gerar/guardar chave de upload, configurar Play App Signing e decidir migracao do beta para loja. |
| 3. Exclusao | Endpoints autenticados, reautenticacao recente, bloqueio, transferencia explicita, worker retomavel, limpeza recursiva, tela/protocolo, pagina web e testes Auth/Firestore. | Deploy coordenado backend/regras, chave Web restrita/configurada, pagina realmente acessivel e teste nativo de cache/FCM. Retencao de telemetria/backups e operacao documentadas, nao automatizadas nesta rotina. |
| 4. Data Safety | Inventario por SDK, dados explicitos/automaticos separados; campos de igreja/e-mail no suporte e identificadores publicitarios no AAB identificados. | Revisao do Console e preenchimento pelo proprietario. Politica de privacidade/retencao final ainda precisam de aprovacao. |
| 5. Artefato | AAB real validado por bundletool, manifesto inspecionado, ELF verificado e APK derivado validado com zipalign -P 16. | Execucao em Android 16 KB real/emulado e testes de instalacao/update pela loja; AAB publicavel depende da chave do proprietario. |

## Artefatos e resultados concretos

### Play (sem assinatura)

- Caminho: `build/app/outputs/bundle/playRelease/app-play-release.aab`.
- SHA-256: `C1F8236FED30F5F5E3C1150169683D6A3449F69B74629F3A1B64506F6B8B31EB`.
- Tamanho: 56.329.960 bytes. Pacote: `br.com.cifraband.cifra_band`. Versao 1.5.9, codigo 27.
- Manifesto do bundle: minSdk 24, **targetSdk 36**. `REQUEST_INSTALL_PACKAGES` ausente. Provider privado do instalador APK ausente; providers de compartilhamento continuam necessarios para exportar arquivos.
- DEX e libapp.so das tres ABIs: identificadores do canal Play presentes; canal/metodo do instalador APK, URL da API GitHub do updater e mensagens exclusivas do downloader ausentes. Junto da selecao compile-time e fontes nativas separadas, isso confirma a remocao do fluxo externo nesse build, nao apenas a ocultacao de um botao.
- Bundle config: `PAGE_ALIGNMENT_16K`. 12 bibliotecas ELF inspecionadas (4 por ABI); todas as 8 bibliotecas de 64 bits passaram na verificacao de segmentos LOAD/alinhamento e congruencia de endereco/offset. ABIs: arm64-v8a, armeabi-v7a, x86_64.
- APK universal DERIVADO localmente do mesmo AAB: `build/play-readiness/play-final-apks/universal.apk`; `zipalign -c -P 16 -v 4` => `Verification successful`.
- O APK derivado foi assinado apenas para inspecao com a chave debug JA EXISTENTE. Isso nao assina o AAB, nao cria chave de upload e nao configura Play App Signing. Nao distribui-lo.
- `jarsigner`/estrutura ZIP confirmam AAB sem assinatura. `publishable:false` no relatorio.
- Ambiente de build: Flutter 3.41.6/Dart 3.11.4; AGP 8.11.1; NDK selecionado 28.2.13676358. O alinhamento foi verificado nos binarios, nao inferido do NDK. Bibliotecas pre-compiladas dos SDKs nao necessariamente usam o mesmo NDK.
- Nao havia aparelho conectado nem imagem Android 16 KB instalada para execucao. Validacao estatica NAO equivale a teste de runtime/pre-launch report.

### Direct (beta preservado)

- Caminho: `build/app/outputs/flutter-apk/app-direct-release.apk`; compilou sem chave/configuracao Play.
- `REQUEST_INSTALL_PACKAGES` e identificadores do instalador/downloader presentes; identificador Play ausente.
- Certificado SHA-256: `9012b9d3b3f2f2d81305d1f55efc23ab2ad4adf3d09aa3e1d77f89f0f05f5d16`, igual ao APK legado `releases/cifra-band-1.5.1-build-19.apk`.
- Nome de saida mudou para `app-direct-release.apk`; scripts externos que usavam `app-release.apk` precisam ajustar o caminho antes de uma futura distribuicao. Nenhum script de publicacao foi executado.

## Evidencias e reproducao

- `build/play-readiness/artifact-report.json`: resumo estruturado do AAB final.
- `build/play-readiness/C1F8236FED30/`: manifesto, bundle config, validacao e relatorio ELF/canais extraidos do AAB final.
- `build/play-readiness/direct-native.json`, `direct-certificate.txt`, `legacy-certificate.txt`, `direct-permissions.txt`: comparacao Direct.
- `build/play-readiness/zipalign-final.txt`: validacao do APK derivado.
- `tool/inspect_play_aab.ps1` + `tool/inspect_native_artifact.cjs`: repetem a inspecao. bundletool 1.18.3 foi obtido do repositorio oficial Google; SHA-256 do JAR `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`, conferido com digest do release.
- `build/stabilization/play-signing-guard-final.txt`: falha esperada sem chave Play.
- `build/stabilization/direct-task-graph-final.txt`: ausencia de tarefas Play no canal direto.

## Testes

Os logs de cada etapa estao em `build/stabilization/`: `play-01-channels`, `play-02-signing`, `play-03-deletion`, `play-04-data-safety`, `play-05-final-verified`. Rodadas intermediarias com falhas foram preservadas; nao sao evidencias de aprovacao. Na ultima rodada, conferir os arquivos com sufixo `final-verified`.

- Etapas 1/2: 118 Flutter + 1 exclusivo Play ignorado no canal Direct; 32 emulador Firestore; 25 Node. O teste exclusivo Play foi executado separadamente.
- Etapas 3/4: 119 Flutter + 1 ignorado no canal Direct; 37 Auth/Firestore; 26 Node.
- Rodada final `play-05-final-verified`: **121 Flutter aprovados**, 1 teste exclusivo Play ignorado no canal Direct; **37 Auth/Firestore aprovados**; **27 Node aprovados**. Depois, `flutter test --no-pub --flavor play test/play_update_test.dart` aprovou **2/2**, incluindo o teste ignorado na rodada Direct.
- `flutter analyze`: **0 erros, 0 warnings, 142 apontamentos informativos de estilo**. O comando retorna 1 por esses apontamentos; o script verifica explicitamente erros/warnings antes de aceitar a etapa. Nao e correto dizer que o analisador ficou sem apontamentos.
- Playwright: pagina de exclusao testada em 360 e 1280 px, sem overflow/erro JS, com login simulado, sucessor, confirmacao e consulta. Screenshots em `build/play-readiness/screenshots/`; nenhuma conta real foi usada.
- Testes de widget adicionais: confirmacao obrigatoria, senha, falha de carregamento e recuperacao em 320 px/fonte ampliada.
- Aviso nao bloqueante do Flutter no build: referencia a fonte CupertinoIcons nao incluida. Nenhum erro de compilacao; revisar os icones Cupertino em smoke test visual antes de publicar.

## Documentacao de operacao

- `docs/PLAY_SIGNING.md`: passos privados de chave, comandos das flavors e migracao de assinatura.
- `docs/ACCOUNT_DELETION.md`: endpoints, limites, config/deploy web, monitoramento e emuladores.
- `docs/PLAY_DATA_SAFETY.md`: inventario e configuracoes que ainda devem ser verificadas pelo proprietario.

Fontes tecnicas: [Android 16 KB](https://developer.android.com/guide/practices/page-sizes), [bundletool Google](https://github.com/google/bundletool/releases/tag/1.18.3), [assinatura Android](https://developer.android.com/studio/publish/app-signing), [teste de In-App Updates](https://developer.android.com/guide/playcore/in-app-updates/test).
