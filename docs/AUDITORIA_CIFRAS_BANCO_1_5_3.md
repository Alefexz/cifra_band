# Auditoria de cifras e banco - 1.5.3+21

## Problemas confirmados e correcoes

### 1. Permission-denied ao salvar na setlist

A rota /add-song recebia apenas um ID. AddSongScreen tentava ler schedules/{id} para decidir se o destino era uma escala. Quando o ID pertencia a uma setlist, a regra de leitura da escala nao conseguia autorizar o documento inexistente e interrompia o fluxo antes da gravacao.

Correcao: SongDestination identifica explicitamente setlist ou escala. A setlist grava songs/{id} e atualiza setlists/{id}.songIds no mesmo batch. Falha de permissao nao cria musica orfa. Escalas continuam utilizando suggested_songs. Erro de notificacao posterior nao transforma uma sugestao salva em erro de salvamento.

### 2. Acordes sem letra vindos do Cifras Gospel Online

O extrator desse provedor concatenava somente pre. Nas quatro paginas afetadas, acordes estavam em pre.wp-block-verse e palavras cantadas em p.wp-block-paragraph. Os paragrafos nunca eram copiados.

Correcao: extracao alternada de acordes e paragrafos em ordem de documento, preservando espacos e quebras. O extrator geral tambem preserva br, combina versos em blocos irmaos e prioriza texto com letra sobre tablatura longa.

### 3. Cache perpetuava o defeito

O backend aceitava quatro acordes ou uma tablatura como prova suficiente de cifra. O cliente lia global_cifras diretamente e abria o resultado sem validar letra. A descoberta tambem usava apenas comprimento minimo de 80 caracteres.

Correcao: validacao de letra e acordes na entrada do backend, cache de memoria, leitura/escrita do cache global, datasource Flutter e abertura de itens da descoberta. Conteudo rejeitado no cache permite nova busca. Uma busca sem resultado nao afirma que a cifra inexiste. Cifras antigas locais continuam acessiveis, mas mostram aviso e uma acao para buscar outra versao.

Limite: a verificacao detecta ausencia ou insuficiencia estrutural de letra. Nao prova que todos os versos existem, que o arranjo corresponde a uma gravacao especifica ou que a harmonia publicada pelo site esta correta.

### 4. Tom menor e capo na revisao

A lista de tons da revisao so tinha tons maiores e usava C como fallback. Alterar tom/capo mudava metadados sem mudar os acordes salvos.

Correcao: preservacao de tons menores e grafias recebidas da fonte; transposicao do conteudo para o tom e capo escolhidos. A previa e a gravacao usam a mesma preparacao. A transposicao preserva letra e nao converte modo maior em menor. Tablaturas nao sao recalculadas; iniciam recolhidas e podem ser ativadas pelo usuario.

### 5. Carregamento e leitura das setlists

StreamBuilder e FutureBuilder ignoravam hasError, mostrando carregamento indefinido. O controller nao observava a troca de conta. O modelo aceitava apenas updatedAt numerico.

Correcao: erros visiveis com nova tentativa, controller observando autenticacao e suporte a Timestamp, milissegundos e data textual. Reabertura da cifra preserva referencia, BPM e observacoes.

### 6. Permissoes de compartilhamento

As leituras mantem a consulta OR usada no app: ownerId == uid ou sharedWith contendo uid. Nas atualizacoes, o dono pode editar os campos da setlist, mas nao transferir ownership. O colaborador pode adicionar musicas e sair do compartilhamento; nao pode trocar dono, renomear, compartilhar com terceiros ou remover musicas existentes.

## Banco real inspecionado

- 258 documentos em global_cifras: quatro falhavam na verificacao de letra.
- 8 documentos em songs: todos passaram na verificacao estrutural.
- 6 documentos em setlists: updatedAt numerico nos documentos inspecionados.
- Nenhuma cifra pessoal ou versao oficial foi apagada ou substituida.

As quatro entradas globais reparadas a partir das mesmas paginas de origem:

| Entrada solicitada no cache | Fonte | Linhas de letra apos reparo |
| --- | --- | --- |
| ComMusic - Jesus, o Plano Perfeito | Cifras Gospel Online / Renascer Praise | 52 |
| Isaias Saad - Ainda Que a Figueira | Cifras Gospel Online / Fernandinho | 58 |
| Pr. Jocymar Fonseca - Porque Ele Vive | Cifras Gospel Online | 34 |
| Trazendo a Arca - Marca da Promessa | Cifras Gospel Online / Davi Sacer | 50 |

Os nomes da solicitacao e da fonte podem divergir devido ao fallback de versao ja existente. O reparo preservou a pagina e os metadados de origem; nao transformou covers em gravacoes oficiais. Backup anterior em build/global-cache-backup.json, somente neste computador. Atualizacoes usaram precondicao de updateTime para nao sobrescrever uma mudanca concorrente.

Nova leitura dos 258 documentos apos os reparos: nenhuma falha de letra/acordes pelo validador. Isso nao significa auditoria musical humana de todas as cifras.

## Verificacao

- Testes Flutter: destinos, tom menor, capo, preservacao de letra, validacao de conteudo e datas; regressao de transposicao, simplificacao e diagramas existente.
- Testes Node: sete cenarios incluindo o layout pre/paragrafo responsavel pela perda de letra.
- Emulador Firestore: 11 testes, incluindo reproducao do bug antigo, consulta OR, dono, colaborador, documento legado, estranho, batch atomico, saida do compartilhamento e sugestao em escala.
- Busca real sem cache no motor: E Ele / Drops INA, Porque Ele Vive / Harpa Crista, Grandioso Es Tu / Harpa Crista e Galileu / Fernandinho retornaram acordes e letra.
- Analise estatica: avisos de estilo e APIs depreciadas preexistentes no projeto; nao equivalem a falhas de compilacao.

## Limites da verificacao

O nome exato do hino relatado nao foi informado. Foi identificado e reparado um Porque Ele Vive sem letra no banco, mas nao se pode afirmar que era o mesmo pedido do usuario. Nao foi feita instalacao pelo USB nem teste manual desta compilacao no celular do usuario.

Arquivos centrais: lib/features/songs/presentation/screens/add_song_screen.dart, lib/features/songs/domain/song_arrangement.dart, lib/features/songs/domain/song_content_quality.dart, lib/features/songs/data/datasources/song_scraper_datasource.dart, lib/features/setlist/presentation/screens/setlist_detail_screen.dart e firestore.rules. Backend em functions/server.js e functions/lib/chord-content.js (repositorio cifraband-api separado).

## Publicacao

Versao 1.5.3, build 21; minimo 21 por se tratar de correcao de falha critica. APK destinado ao GitHub Release v1.5.3, com link direto de download. Conferir identidade do pacote, versionCode, certificado e SHA-256 antes de anunciar pelo /app-version. A publicacao do backend deve acontecer somente depois de o APK estar acessivel.

Publicacao concluida em 10/09/2026:

- App: commit 5ab364b, tag v1.5.3, Release publicado com APK de 67.199.294 bytes.
- Backend: commit 88f3449 enviado ao cifraband-api; Render confirmou latestBuild=21, minimumBuild=21 e updateRequired=true em 2026-09-10T18:14:48.833Z.
- Download publico verificado com HTTP 200: https://github.com/Alefexz/cifra_band/releases/download/v1.5.3/cifra-band-1.5.3-build-21.apk
- SHA-256 do APK e do asset no GitHub: 78d5715587bfdf2dcb1b5eeeb321b00e84657cd1ae28e133a05a6d0384d9495a.
- Pacote br.com.cifraband.cifra_band, versionName 1.5.3, versionCode 21; certificado identico ao APK 1.5.2 do beta.
- Regras Firestore publicadas com sucesso. Busca de producao sem token continuou bloqueada com HTTP 401.
- 40 testes automatizados passaram: 22 Flutter, 7 Node e 11 Firestore.
- Nova auditoria apos o deploy: 258 cifras globais, oito musicas e seis setlists; nenhuma cifra global sem letra/acordes suficientes segundo o validador.
