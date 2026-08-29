# Cifra Band

Cifra Band é um aplicativo Flutter para ministérios de louvor organizarem escalas, repertórios e cifras em um único fluxo. O projeto nasceu para resolver a rotina real de bandas de igreja: montar equipes, aprovar músicas, consultar cifras, transpor tons, salvar setlists offline e manter todos avisados por notificações.

O posicionamento do app não é ser apenas uma biblioteca de cifras. Ele funciona como uma ferramenta operacional para líderes e músicos, unindo gestão de culto, comunicação da equipe e execução musical.

## Principais Recursos

- Autenticação com Firebase Auth.
- Gestão de ministérios, membros, funções e convites.
- Criação de escalas por culto/evento.
- Confirmação ou recusa de participação pelo músico.
- Notificações push para escala, aceite, recusa, remoção, atualização, cancelamento e movimentações do repertório.
- Sugestão, votação, aprovação e rejeição de músicas.
- Setlist oficial do culto com ordem editável.
- Modo culto com navegação por swipe entre músicas.
- Indicador visual da música atual na setlist.
- Cifras com transposição de tom, capo e preservação de acordes menores.
- Histórico das últimas 20 músicas tocadas.
- Favoritos pessoais.
- Campos de referência de ensaio, BPM e observações.
- Setlists offline para uso em locais com internet instável.
- Disponibilidade do músico para evitar escalas em datas bloqueadas.
- Lembretes locais antes dos cultos em que o músico foi escalado.

## Stack Técnica

- Flutter e Dart.
- Firebase Auth, Cloud Firestore e Firebase Cloud Messaging.
- Render para API Node.js de notificações.
- SharedPreferences para cache local/offline.
- GoRouter para navegação.
- Riverpod para estado.

## Arquitetura

O app usa Firebase como base de autenticação e dados em tempo real. As notificações push passam por uma API própria hospedada no Render, permitindo controle do envio e separação clara entre app, banco e backend de mensageria.

As regras do Firestore foram estruturadas para proteger dados por igreja/ministério, evitando acesso amplo indevido e permitindo apenas operações compatíveis com o papel do usuário.

## Configuração Local

Por segurança, os arquivos reais de configuração Firebase não ficam versionados neste repositório público. Para rodar o projeto em outra máquina, gere as configurações com FlutterFire CLI ou adicione localmente:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`, quando o alvo iOS for usado
- `.firebaserc` e `firebase.json`, quando for publicar regras pelo Firebase CLI

Esses arquivos devem permanecer somente no ambiente local ou em secrets protegidos de CI/CD.

## Status

MVP avançado em fase de beta técnico. O fluxo principal de escala, repertório, setlist, transposição, histórico, offline, disponibilidade e notificações está implementado e validado em build debug.

## NovaStack

Projeto desenvolvido como produto de portfólio da NovaStack, com foco em SaaS mobile para gestão musical de igrejas e equipes de louvor.
