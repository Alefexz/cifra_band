# Correcao de leitura das setlists

## Causa reproduzida

A versao 1.5.6 salva as cifras em setlists/{id}/songs e lista seus documentos com documentId in, em lotes de dez IDs. A regra reutilizava getAfter tanto para criacao atomica quanto para leitura. A consulta de listagem falhava com permission-denied, embora o salvamento e a leitura individual fossem autorizados.

Os testes anteriores verificavam getDoc apos o batch, mas nao a consulta getDocs usada pela tela. Ao incluir a consulta real antes da correcao, os dois testes de dono e colaborador falharam.

## Correcao

- Leitura usa get para conferir o estado persistido da setlist pai.
- Criacao continua usando getAfter para validar o batch atomico com a inclusao do ID na setlist.
- Permissoes continuam restritas ao dono e aos colaboradores. Nao foi liberada leitura publica, nem acesso as cifras de outra setlist.
- Nenhuma cifra ou setlist foi apagada ou regravada.

## Validacao

26 testes de regras e push passaram, incluindo salvar e listar como dono e colaborador, setlist antiga sem sharedWith, onze musicas em dois lotes, revogacao de compartilhamento e bloqueio de estranhos, usuarios sem login e documentos sem pai.

Publicacao somente das regras do Firestore no projeto cifra-band. A correcao atende o APK 1.5.6+24 ja instalado; nao depende de novo APK, release ou deploy no Render. Para refazer a consulta, usar Tentar novamente ou reabrir a setlist. Nao foi realizado teste no aparelho do usuario nesta correcao.
