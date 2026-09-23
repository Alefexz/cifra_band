# Exclusao de conta: operacao e validacao

Implementacao local; nao foi feito deploy. Endpoint/pagina so existirao publicamente depois do deploy autorizado do backend e das regras.

## Fluxo

- POST `/account/deletion/options`: Bearer Firebase verificado/revogacao checada; lista ministerios administrados e sucessores elegiveis.
- POST `/account/deletion/request`: exige login ha no maximo 5 minutos, `confirm:true`, protocolo aleatorio de 32 bytes em hex e mapa `successors`. O UID vem exclusivamente do token, nunca do corpo.
- Transacao cria bloqueio e job; transfere administracao apenas a sucessor explicitamente escolhido do mesmo ministerio. Ministerios sem outros membros sao removidos no final. Criacao de convite/entrada nao contorna esse estado.
- Worker desabilita Auth/revoga tokens, percorre colecoes paginadas, usa recursiveDelete e busca de subcolecoes orfas. Lease/checkpoint permitem retomada apos interrupcao. Falha continua como `retry`, nunca como sucesso.
- Requisicoes autenticadas ja admitidas na instancia sao drenadas antes da limpeza. A configuracao atual e de uma instancia Render; antes de escalar para varias replicas, substituir esse controle local por uma barreira distribuida de escritas. Nao certifique exclusao concorrente multi-instancia com o teste atual.
- POST `/account/deletion/status`: consulta sem login pelo protocolo secreto de alta entropia, nao pelo UID/e-mail. Retorna somente estado/fase/datas. Nao registra protocolo em URL. Guarde o protocolo; ele permite acompanhar o pedido, nao acessar dados da conta.
- Conta Auth apagada no final; protocolos/bloqueios minimos removidos pelo worker 30 dias depois. O Render precisa estar ativo para executar a fila/expiracao. Ha retomada na inicializacao e a cada minuto enquanto o processo esta ativo.

## Dados abrangidos

`users/{uid}` com todas as subcolecoes; `public_profiles/{uid}`; contatos; dispositivos FCM; setlists proprias com musicas; referencia em sharedWith/friends; musicas/contribuicoes identificadas por UID; membros/votos/sugestoes nas escalas; rehearsal_status inclusive orfaos; versoes da biblioteca e autoria; tickets proprios, mensagens/respostas administrativas/handled_by em tickets alheios. Trabalhos de outros integrantes sao preservados. Caches globais sem vinculo de usuario nao sao removidos.

No aparelho solicitante: favoritos/anotacoes/downloads por UID e legado, token FCM, avisos locais, sessao Auth, cache persistente Firestore, contexto diagnostico e identificacao local Analytics/Crashlytics. A tela final exige fechar/reabrir o processo porque Firestore foi encerrado para apagar seu cache. Marcador local permite tentar novamente se a limpeza falhar. Escritas tardias de favoritos/notas/downloads do UID excluido sao bloqueadas.

Outros aparelhos offline, copias de terceiros, backups e telemetria remota nao podem ser apagados por esta rotina. Ver `PLAY_DATA_SAFETY.md`. Novos campos/colecoes com UID precisam ser adicionados ao inventario/testes antes de uso. Dados legados sem autoria rastreavel precisam de procedimento manual, sem apagar dados alheios por suposicao.

## Pagina publica sem app

URL preparada: `https://cifraband-api.onrender.com/account-deletion`.

1. No Firebase/Google Cloud, obter/configurar uma chave de API Web adequada ao projeto Auth; nao reutilizar cegamente chave restrita ao pacote Android. Chave Web nao e conta de servico nem segredo de admin.
2. Restringir APIs necessarias (Identity Toolkit) e origens/referenciadores de acordo com a configuracao de chave; testar signInWithPassword a partir do dominio HTTPS real. Configurar `FIREBASE_WEB_API_KEY` no backend.
3. Pagina envia senha somente ao Google por HTTPS; token fica apenas na memoria da pagina, nao em localStorage. CSP restringe scripts/conexoes; nao ha bibliotecas remotas nem analytics nesta pagina.
4. Sem a variavel, a pagina explica que a solicitacao web nao esta configurada. Isso ainda e PENDENCIA para publicacao, nao conformidade concluida.
5. Fazer deploy coordenado do backend + firestore.rules, verificar URL publica/config e fluxo com conta de teste. Nao publicar a URL como funcional na Play antes disso.
6. Manter acompanhamento de jobs `queued/running/retry`, alarmes de atraso e atendimento humano em indisponibilidades prolongadas. Processamento retomavel nao equivale a disponibilidade garantida do Render Free.

## Testes executaveis

`powershell -File tool/check_stabilization.ps1 -Item play-03-deletion` roda Flutter, Auth+Firestore em `demo-cifra-band` e Node. Teste recusa execucao sem hosts locais de emulador. Cobertura: autenticacao, login recente, confirmacao, sucessor invalido, bloqueio de token antigo nas regras/API, impossibilidade de remover o bloqueio, UID do corpo ignorado, exclusao recursiva/orfaos, refresh token invalidado, preservacao de outro membro, protocolo sem PII, retomada e pagina com CSP. Limpeza local por UID testada com preferencias simuladas; comportamento nativo de clearPersistence/FCM precisa ainda de smoke test no aparelho.

Nao foram executadas exclusoes em producao nem criadas chaves/contas reais para estes testes.
