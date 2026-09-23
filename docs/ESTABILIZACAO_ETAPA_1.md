# Etapa 1 de estabilizacao

Concluida localmente em 21/09/2026, sobre a base 1.5.9+27. Sem APK, alteracao de numero de versao, commit, push, deploy ou mudancas em producao.

## Pre-requisito

A correcao anterior dos diagramas ja estava aplicada no commit `03b0e57`. Os oito testes de `test/chord_diagrams_test.dart` foram executados e passaram antes das alteracoes desta etapa. Nao foram executadas sessoes paralelas editando esses arquivos.

## 1. Capotraste, forma e acorde real

Causa confirmada: o acorde escrito na cifra era usado com a tonalidade real para calcular notas e graus.

Agora `_soundingChord` converte a forma para o acorde real pelo intervalo entre `_currentShape` e `_currentPitch`, usando `TransposerEngine.transposeChord`. Tanto o modal quanto a lista de estudo recebem a analise do acorde real. O clique em um card conserva o acorde escrito de origem para nao aplicar a conversao duas vezes.

O violao conserva a digitacao da forma e identifica o capo; o teclado usa as notas reais. Sem capo, a conversao nao e aplicada.

Aceite automatizado: forma C, capo 2, tom D apresenta grau 1/I e D-F#-A; violao mantem a forma C. Com capo 0, continua C-E-G e grau 1/I.

Arquivo principal: [cifra_screen.dart](C:/Users/nioti/cifra_band/lib/features/songs/presentation/screens/cifra_screen.dart:1155).

## 2. Retencao dos downloads

Causa confirmada: `skip(20)` removia os payloads antigos, enquanto `take(20)` descartava as entradas do indice.

Esse corte foi removido, sem introduzir outro limite. Baixar 21 setlists preserva todas, inclusive ao reconstruir o armazenamento local. Exclusao continua sendo uma acao explicita. O teste antigo que exigia descarte automatico foi atualizado para a nova regra.

Esta correcao nao transforma SharedPreferences em um banco transacional nem resolve todos os riscos de espaco/disco discutidos na auditoria; essa migracao de armazenamento nao foi incluida no escopo solicitado.

Arquivo: [offline_setlist_service.dart](C:/Users/nioti/cifra_band/lib/core/services/offline_setlist_service.dart:233).

## 3. Favoritos e anotacoes por conta

Causa confirmada: favoritos e anotacoes usavam chaves sem UID.

Foi adicionado `AccountLocalDataService`, com armazenamento vinculado ao UID e notificacao da troca de sessao. As telas de favoritos e cifra limpam o estado de favoritos; uma anotacao aberta tem seu texto limpo e nao pode ser gravada por outra conta.

A inicializacao captura a sessao restaurada pelo Firebase antes de mostrar o login. A primeira migracao grava `legacy_local_data_owner`, inclusive quando nao existe usuario. Assim:

- Conta A ja autenticada: migra os dados antigos para A.
- Primeira abertura sem conta: dados antigos ficam sem associacao, sem serem entregues ao proximo login.
- Migracao interrompida: o proprietario permanece fixado; B nao pode assumir os dados de A.
- Favoritos ja existentes: preserva os existentes e acrescenta os legados ainda ausentes, sem duplicar por ID.
- Anotacao ja migrada: nao e sobrescrita por uma copia legada.

Nao houve copia de dados reais ou migracao de contas em producao. A migracao sera executada no aparelho somente se/quando uma versao contendo este codigo for instalada.

Arquivo: [account_local_data_service.dart](C:/Users/nioti/cifra_band/lib/core/services/account_local_data_service.dart).

## 4. Manifesto obrigatorio atualizado ao vivo

Causa confirmada: o retorno antecipado apos mostrar `required_app_update` impedia a consulta remota.

O dialogo armazenado continua abrindo imediatamente e bloqueando retorno/adiamento. A consulta ocorre em paralelo e atualiza a versao, URL e notas no mesmo dialogo, alem de persistir o manifesto validado. Uma nova verificacao com o dialogo aberto tambem pode renova-lo, sem duplicar uma consulta ja em andamento.

Respostas HTTP com erro, rede indisponivel, URL insegura, manifesto invalido e versao anterior nao substituem o bloqueio valido. Uma release posterior opcional nao libera uma instalacao que estava abaixo do minimo obrigatorio conhecido.

Testes cobrem renovacao de 6 para 7 e depois 8 com o dialogo aberto, persistencia, bloqueio de retorno, rede indisponivel, HTTP 503, URL invalida e tentativa de retrocesso.

Arquivo: [app_update_service.dart](C:/Users/nioti/cifra_band/lib/core/services/app_update_service.dart:291).

## 5. YouTube fora da resposta critica

Causa confirmada em tres caminhos: cache em memoria, cache global e cifra encontrada sem referencia.

As respostas de cifra agora usam uma funcao comum que envia o JSON antes de agendar o enriquecimento opcional. A fila tem concorrencia limitada, deduplicacao, limite de pendencias e intervalo entre novas tentativas. Erros do YouTube sao tratados sem invalidar a cifra.

O enriquecimento grava somente os campos de referencia no documento correspondente, em transacao, se o conteudo ainda coincidir e nao houver referencia salva. Nao sobrescreve a cifra inteira com uma copia antiga. A fila e de melhor esforco, em memoria: reinicio do processo pode interrompe-la, sem afetar a cifra ja entregue.

No cliente, um acerto no cache passou a chamar `BackendWarmupService`, que usa `/app-version`, timeout limitado e intervalo minimo entre aquecimentos. Foi removido o ping que executava `/searchSong` completo.

Medicao HTTP local com a mesma cifra de teste, sem referencia, e resolucao de YouTube controlada em 300 ms:

| Fluxo | Medida representativa |
|---|---:|
| Antes, aguardando a referencia | 352,4 ms |
| Depois, resposta independente da referencia | 3,8 ms |

Os testes tambem deixam o resolvedor pendente e confirmam que a cifra ainda chega, sem multiplicar jobs duplicados. **Esta e uma medicao local controlada, nao uma promessa de latencia do Render nem um benchmark de scraping em producao.**

Arquivos: [youtube-background.js](C:/Users/nioti/cifra_band/functions/lib/youtube-background.js), [server.js](C:/Users/nioti/cifra_band/functions/server.js:5349), [song_scraper_datasource.dart](C:/Users/nioti/cifra_band/lib/features/songs/data/datasources/song_scraper_datasource.dart).

## 6. Compartilhamento entre ministerios

**Correcao do diagnostico anterior:** no HEAD examinado, o seletor ja consultava `public_profiles`. A afirmacao da auditoria de que ele lia `users/{friendId}` nao correspondia a essa versao. A diferenca foi comunicada antes desta correcao.

O problema confirmado no seletor era esconder silenciosamente amigos quando o perfil publico nao existia ou quando sua consulta falhava. Perfis publicos sao criados por um fluxo separado; contatos legados podem nao te-los.

Foi criado o endpoint autenticado `/members/contacts`, que usa apenas a lista de amigos do proprio chamador. IDs arbitrarios enviados no corpo nao determinam a consulta. Ele le somente o nome dos perfis e retorna ID e nome, sem email, papeis, tokens ou dados do ministerio. Nao depende da existencia de `public_profiles` e nao exige que ambos participem do mesmo ministerio.

O seletor usa essa resposta e apresenta erro com nova tentativa, em vez de sumir com os contatos. A alteracao do compartilhamento continua sujeita as regras Firestore existentes. **Nenhuma regra de `users` foi aberta ou modificada.**

Aceite no emulador: contatos do mesmo e de outro ministerio sem perfil publico sao retornados; ambos conseguem ler a setlist e sua musica apos compartilhamento; leitura do perfil privado de outra igreja e negada; revogacao remove acesso a musica. O teste exercita o handler real com banco emulado e identidade de teste, nao tokens/contas reais.

Arquivos: [member-actions.js](C:/Users/nioti/cifra_band/functions/lib/member-actions.js:104), [setlist_contacts_service.dart](C:/Users/nioti/cifra_band/lib/core/services/setlist_contacts_service.dart), [setlist_detail_screen.dart](C:/Users/nioti/cifra_band/lib/features/setlist/presentation/screens/setlist_detail_screen.dart).

## Rate limit: estado confirmado

Continua **em memoria**, em `rateLimitBuckets = new Map()` no [server.js](C:/Users/nioti/cifra_band/functions/server.js:77). As cotas nao sao compartilhadas entre processos/instancias e sao perdidas ao reiniciar. Nao foi encontrado Redis ou armazenamento persistente nesse mecanismo. Nao foi alterado, pois o pedido extra era verificar e informar.

## Verificacao por item

Depois de cada item foram executados Flutter analyze, Flutter test, a suite Firestore no emulador e os testes Node selecionados. Os resultados abaixo correspondem as rodadas corrigidas, nao as primeiras tentativas com erros de testes.

| Etapa | Flutter | Emulador/regras | Node |
|---|---:|---:|---:|
| 1 - Capo | 91 passaram | 28 passaram | 18 passaram |
| 2 - Offline | 92 passaram | 28 passaram | 18 passaram |
| 3 - Contas | 97 passaram | 28 passaram | 18 passaram |
| 4 - Manifesto | 102 passaram | 28 passaram | 18 passaram |
| 5 - YouTube | 103 passaram | 28 passaram | 22 passaram |
| 6 - Compartilhamento | 105 passaram | 29 passaram | 23 passaram |

Na preparacao houve um getter errado no teste novo do capo, a expectativa antiga de descarte de downloads e uma importacao incorreta do Firebase Admin no teste novo do emulador. Foram corrigidos e as respectivas rodadas repetidas. Isso nao foi ocultado como teste aprovado.

A rodada final consolidada terminou com **105 testes Flutter, 29 da suite do emulador e 23 Node aprovados**. `flutter analyze` apontou **0 erros, 0 warnings e 140 infos**. A rodada esta registrada em `build/stabilization/07-final-review-*`. O codigo de saida de `flutter analyze` foi 1 por infos; o script distingue isso de erros/warnings. Nenhuma regra de lint foi desativada. `git diff --check` passou nos dois repositorios.

Na repeticao final da medicao controlada do item 5, os tempos foram 359,6 ms antes e 5,4 ms depois, novamente sem incluir scraping real ou latencia do Render.

Reproducao: `powershell -NoProfile -ExecutionPolicy Bypass -File tool/check_stabilization.ps1 -Item revisao`. O script usa o projeto ficticio `demo-cifra-band` para o emulador. Os logs ficam em `build/stabilization`, que e uma pasta temporaria ignorada pelo Git.

## Limites e publicacao futura

- Nao foi feito teste em celular/tablet fisico nesta rodada.
- Nao foi feita validacao de toda a internet, de todas as cifras ou de todos os acordes.
- Os itens fora dos seis pedidos permanecem no backlog da auditoria.
- Versao e manifesto publicados continuam inalterados.
- As alteracoes do backend estao no repositorio separado `functions`; um futuro lancamento deve incluir esse repositorio, nao apenas o Flutter.
- Quando a publicacao for autorizada, o novo endpoint de contatos deve estar disponivel no backend antes de distribuir o cliente que o utiliza.

Esta etapa esta preparada para revisao local. Publicacao depende de autorizacao posterior do usuario.
