# Publicacao 1.5.6+24

Conferida em 13/09/2026.

- App: commit 6d98b7c, tag v1.5.6, release publica no GitHub.
- Backend: commit 44a4c93, enviado ao main e confirmado no Render pelo /app-version.
- Manifesto ao vivo: latestVersion 1.5.6, latestBuild 24, minimumBuild 24, updateRequired true.
- APK: https://github.com/Alefexz/cifra_band/releases/download/v1.5.6/cifra-band-1.5.6-build-24.apk
- Tamanho: 67396066 bytes; HEAD publico retornou HTTP 200 com esse tamanho.
- SHA-256: 344e3374b2c4d277dc4856cdad55e876b569d361e40cd847f3a2e2041e2ad234.
- Assinatura Android preservada para atualizar as instalacoes beta existentes. Ainda usa a identidade de assinatura debug do beta; a migracao para assinatura de distribuicao definitiva exige planejamento separado.
- Migracao aplicada e repetida depois da ativacao das regras: 7 perfis, 6 setlists, 4 referencias de cifras copiadas, nenhuma referencia ausente. Documentos de cifras originais preservados. Backups privados em build/migrations, fora do Git.
- Regras do Firestore publicadas no projeto cifra-band. Removida tambem uma regra privada sem uso no escopo de ministerios; backups de tokens nao sao expostos ao cliente.
- Validacao: 72 testes Flutter, 22 testes de regras/push no emulador e 18 testes Node passaram. Flutter analyze sem erros ou warnings, com avisos informativos de estilo remanescentes.
- Rotas /members/profile, /members/join, /members/schedule, /members/contact e /devices/unregister retornaram HTTP 401 sem autenticacao em producao.
- Consultas reais de catalogo incluiram Jorge & Mateus e os erros "jorgeve mayheus" e "Jorge e Matheus"; a descoberta de Sol Nos Olhos encontrou a pagina do Cifra Club com tom E.

Nao foi feita instalacao por USB nem confirmado recebimento de push em um telefone nesta publicacao. A verificacao do fluxo completo no aparelho cabe ao teste da atualizacao pelo app. Render Free, disponibilidade de terceiros e permissoes de notificacao continuam sendo dependencias externas.
