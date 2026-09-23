# Cifra Band 1.6.0 (build 28)

Canal: APK direto para os aparelhos beta existentes. Nao e publicacao na Play.

## Mudancas

- Central de ensaios com preparacao por musica/integrante e revisao quando o arranjo muda.
- Correcao da analise de acordes e graus com capotraste: forma no violao, notas reais no teclado.
- Downloads de setlists sem descarte automatico ao ultrapassar 20 listas.
- Favoritos, anotacoes e downloads isolados por conta; protecao na troca de usuario.
- Compartilhamento com contatos pelo endpoint autenticado, sem abrir perfis privados.
- Atualizador renova manifestos obrigatorios antigos sem perder o bloqueio de versoes defeituosas.
- Referencia YouTube processada em segundo plano, sem segurar a resposta da cifra.
- Exclusao de conta no perfil, com reautenticacao, protocolo e limpeza retomavel.
- Separacao tecnica dos canais direct e play; o beta continua com seu instalador e assinatura anteriores.

## Validacao antes do rollout

Em 23/09/2026: Flutter 121 aprovados e 1 ignorado (exclusivo Play), Firebase Auth/Firestore emulados 37 aprovados, Node 27 aprovados. Analise sem erros/avisos, com informacoes de estilo preexistentes. Logs em build/stabilization/release-160-*.

Regras Firestore publicadas antes de anunciar o APK. Backend atualizado em duas etapas: primeiro as funcionalidades, depois o manifesto com hash/tamanho do APK publicado.

Minimo permanece build 27. A versao 1.6.0 e opcional para quem esta na 1.5.9; aparelhos abaixo do minimo continuam sujeitos a atualizacao obrigatoria.

## Limites

- Nao houve instalacao por USB nem teste fisico nesta publicacao.
- Push depende de registro/token valido, permissao do aparelho e entrega FCM; nao equivale a instalacao automatica. Android solicita confirmacao para instalar.
- Aparelhos muito antigos sem atualizador funcional podem precisar de instalacao manual do APK, preservando a assinatura.
- A pagina publica de exclusao depende de FIREBASE_WEB_API_KEY para receber pedidos fora do app. Essa configuracao ainda precisa ser validada antes da Play; a exclusao autenticada dentro do app usa o Firebase ja configurado.
- Assinatura Play, formulario Data Safety e decisao sobre licenciamento continuam pendentes. Nenhuma chave nova foi gerada.
- Testes de exclusao usam emuladores. Nao foram apagadas contas/dados reais para validar esta release.
