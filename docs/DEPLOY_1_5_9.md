# Publicacao 1.5.9+27

- App: 3d3eff4, tag v1.5.9.
- Backend: 7daa21a, Render confirmado em 2026-09-15T10:21:42.021Z.
- Manifesto: latestVersion 1.5.9, latestBuild 27, minimumBuild 27, updateRequired true.
- APK: https://github.com/Alefexz/cifra_band/releases/download/v1.5.9/cifra-band-1.5.9-build-27.apk
- GitHub validou SHA-256 e tamanho; HEAD publico retornou HTTP 200, 67428886 bytes.
- SHA-256: 8051b48063c9e91923e7cad8f680f9f4fe7559c7be2fcadca86125722dbde8e1.
- Assinatura SHA-256 preservada: 9012b9d3b3f2f2d81305d1f55efc23ab2ad4adf3d09aa3e1d77f89f0f05f5d16.
- 89 testes Flutter e 18 testes Node passaram. Analise dos sete arquivos Dart alterados/testados sem apontamentos.
- Capturas e teste de cifra real em 320x640, escala de texto 1.3, temas claro/escuro. Verificados Tom Real e atalhos restaurados, feedback apenas no painel de configuracoes, modal de acordes.
- Testes novos cobrem atualizacao de contagem/nome/remocao sem refresh, cancelamento da assinatura na troca de conta, logout, falha de criacao e recuperacao de erro do stream.
- Nenhuma alteracao nas regras Firestore ou migracao de dados.
- Sem instalacao por USB e sem confirmacao de instalacao/recebimento de push em aparelhos fisicos.
- Instalacoes antigas sem atualizador precisam de uma instalacao manual por cima. Ver ATUALIZACAO_VERSOES_ANTIGAS.md; o tablet relatado ainda nao foi inspecionado.
