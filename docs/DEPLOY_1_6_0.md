# Deploy 1.6.0 build 28

Concluido em 23/09/2026 para o canal APK direto.

- App/tag v1.6.0: 435d7abca44dec6f1acc7833eafaaef4adaf98f4.
- Backend funcional: 2d49cff; manifesto final: 89b60fd. Ambos enviados a main e implantados pelo Render.
- Firestore: firebase deploy --only firestore:rules --project cifra-band concluido; compilacao aceita, com avisos de helpers legados nao utilizados.
- Release publica: https://github.com/Alefexz/cifra_band/releases/tag/v1.6.0
- APK: https://github.com/Alefexz/cifra_band/releases/download/v1.6.0/cifra-band-1.6.0-build-28.apk
- Tamanho: 68019046 bytes. HEAD publico HTTP 200.
- SHA-256 local e digest do asset GitHub: 687579b3b35b5053653fe7a9497da2b6c22b9d39b587f08db63a86aab2525949.
- Certificado SHA-256: 9012b9d3b3f2f2d81305d1f55efc23ab2ad4adf3d09aa3e1d77f89f0f05f5d16 (assinatura legada preservada).
- apksigner verify aprovado; pacote br.com.cifraband.cifra_band, versionCode 28, versionName 1.6.0, minSDK 24, targetSDK 36; ABIs arm64-v8a, armeabi-v7a, x86_64.
- Manifesto vivo conferido em 2026-09-23T22:09:43Z: latestBuild 28, minimumBuild 27, updateRequired false, URL/hash/tamanho correspondentes ao APK.
- GET /account-deletion HTTP 200 com CSP; POST /account/deletion/options sem token HTTP 401. Nenhuma exclusao real executada.
- FIREBASE_WEB_API_KEY ainda ausente em producao; pagina informativa publicada, solicitacao web externa ainda pendente. Fluxo autenticado do app nao depende dessa variavel.

## Testes

Flutter: 121 aprovados, 1 ignorado exclusivo Play. Auth/Firestore emulados: 37 aprovados. Node: 27 aprovados, repetidos apos atualizar o manifesto. Flutter analyze: zero erros/avisos, 142 informacoes; nao e uma analise completamente limpa. Build direct release concluido.

Nao houve teste de instalacao em aparelho fisico nesta execucao. A consulta de manifesto aciona o worker existente de push, mas nao foi auditada a entrega individual de notificacoes. Token, permissao e conectividade do aparelho condicionam a entrega. A instalacao depende da confirmacao do usuario.

Nada foi publicado na Play Console. Licenciamento, assinatura Play, formulario Data Safety e ativacao/validacao da solicitacao web seguem fora deste rollout. Ver RELEASE_1_6_0.md para escopo e limites.
