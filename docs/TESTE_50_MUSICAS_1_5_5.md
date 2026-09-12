# Teste de 50 musicas - Cifra Band 1.5.5

Data: 2026-09-12. APK: 1.5.5+23.

## Resultado observado

- 50 consultas distintas, com 40 gospels/hinos (recentes e antigos) e 10 classicos populares.
- 50/50 retornaram o titulo e artista esperados em algum ponto da lista.
- 48/50 em primeiro lugar (96%); as mesmas 48 entre os cinco primeiros.
- Alvo Mais Que a Neve e Vencendo Vem Jesus: versao atribuida a Harpa Crista em 13o; interpretacoes de outros artistas do mesmo hino vieram antes.
- Nenhuma fonte sinalizou falha parcial nesta rodada.
- Tempo medio para concluir os catalogos: 461 ms; percentil 95: 933 ms; maximo: 1132 ms.
- Medicao feita nesta maquina/rede, sem token Firebase no benchmark. Nao mede cold start do Render, download de APK ou abertura de cifra.
- O numero 545 tem metadados locais verificados; seu primeiro resultado nao depende da rede.

## Escopo e limites

Chamadas reais ao servico de busca do app (Deezer e Apple). O criterio automatico procura o titulo e artista normalizados esperados; ele nao compara a gravacao, o arranjo ou a letra completa. Encontrar metadados nao significa abrir uma cifra valida. Nao foram abertas e auditadas musicalmente 50 cifras nesta rodada.

Nao ha evidencia para prometer 99% de acerto universal. Os dois casos de Harpa ainda precisam de melhor tratamento de autoria/colecao; nao foram escondidos nem retirados da amostra.

## Lista completa

| # | Musica | Artista esperado | Posicao final | Primeiro resultado (ms) | Consulta completa (ms) |
| --- | --- | --- | ---: | ---: | ---: |
| 1 | A Casa É Sua | Casa Worship | 1 | 737 | 933 |
| 2 | Porque Ele Vive - 545 | Harpa Cristã | 1 | 1 | 391 |
| 3 | Faz Chover | Fernandinho | 1 | 88 | 327 |
| 4 | Eu Navegarei | Gabriela Rocha | 1 | 99 | 293 |
| 5 | Ressuscita-me | Aline Barros | 1 | 151 | 308 |
| 6 | Advogado Fiel | Bruna Karla | 1 | 99 | 476 |
| 7 | Escudo | Voz da Verdade | 1 | 162 | 459 |
| 8 | Aquieta Minh'alma | Ministério Zoe | 1 | 68 | 317 |
| 9 | Deserto | Maria Marçal | 1 | 83 | 361 |
| 10 | Me Atraiu | Gabriela Rocha | 1 | 166 | 733 |
| 11 | Ousado Amor | Isaías Saad | 1 | 87 | 404 |
| 12 | Bondade de Deus | Isaías Saad | 1 | 362 | 396 |
| 13 | Todavia Me Alegrarei | Samuel Messias | 1 | 163 | 366 |
| 14 | Algo Novo | Kemuel | 1 | 84 | 392 |
| 15 | Lugar Secreto | Gabriela Rocha | 1 | 171 | 426 |
| 16 | Deus Proverá | Gabriela Gomes | 1 | 86 | 378 |
| 17 | Em Teus Braços | Laura Souguellis | 1 | 297 | 476 |
| 18 | Pra Sempre | Fernandinho | 1 | 166 | 303 |
| 19 | Maranata | Ministério Avivah | 1 | 96 | 313 |
| 20 | Galileu | Fernandinho | 1 | 154 | 434 |
| 21 | Ninguém Explica Deus | Preto no Branco | 1 | 156 | 285 |
| 22 | Lindo Momento | Julliany Souza | 1 | 147 | 358 |
| 23 | Alfa e Ômega | Marine Friesen | 1 | 78 | 357 |
| 24 | Grandioso És Tu | Harpa Cristã | 1 | 107 | 1132 |
| 25 | Alvo Mais Que a Neve | Harpa Cristã | 13 | 160 | 534 |
| 26 | Vencendo Vem Jesus | Harpa Cristã | 13 | 192 | 420 |
| 27 | Firme nas Promessas | Harpa Cristã | 1 | 89 | 418 |
| 28 | Mais Perto Quero Estar | Harpa Cristã | 1 | 103 | 826 |
| 29 | Sossegai | Harpa Cristã | 1 | 83 | 376 |
| 30 | Deus de Promessas | Toque no Altar | 1 | 156 | 691 |
| 31 | Te Agradeço | Kleber Lucas | 1 | 72 | 306 |
| 32 | Tua Graça Me Basta | Toque no Altar | 1 | 160 | 315 |
| 33 | Marca da Promessa | Trazendo a Arca | 1 | 88 | 406 |
| 34 | Sonda-me, Usa-me | Aline Barros | 1 | 88 | 462 |
| 35 | Pelo Sangue | Renascer Praise | 1 | 157 | 306 |
| 36 | Deus Cuida de Mim | Kleber Lucas | 1 | 92 | 514 |
| 37 | Raridade | Anderson Freire | 1 | 117 | 447 |
| 38 | Sabor de Mel | Damares | 1 | 315 | 754 |
| 39 | Preciso de Ti | Diante do Trono | 1 | 101 | 364 |
| 40 | A Ele a Glória | Diante do Trono | 1 | 144 | 300 |
| 41 | Tempo Perdido | Legião Urbana | 1 | 154 | 439 |
| 42 | Pais e Filhos | Legião Urbana | 1 | 331 | 436 |
| 43 | Evidências | Chitãozinho | 1 | 177 | 1069 |
| 44 | Como É Grande o Meu Amor Por Você | Roberto Carlos | 1 | 101 | 428 |
| 45 | Asa Branca | Luiz Gonzaga | 1 | 149 | 459 |
| 46 | Tocando em Frente | Almir Sater | 1 | 94 | 357 |
| 47 | Romaria | Renato Teixeira | 1 | 187 | 634 |
| 48 | Canteiros | Fagner | 1 | 74 | 286 |
| 49 | Trem das Onze | Adoniran Barbosa | 1 | 101 | 331 |
| 50 | Aquarela | Toquinho | 1 | 394 | 559 |

## Outras verificacoes

- Flutter: 50 testes passaram, incluindo ranking, provedores, erros parciais, resultados progressivos, respostas antigas, abas e tela estreita com texto ampliado.
- Backend Node: 13 testes passaram (indice, conteudo de cifra e versao).
- Emulador Firestore/notificacoes: 18 testes passaram.
- Analise estatica dos arquivos de busca alterados: sem problemas.
- Indice local construido sobre leitura real de 259 documentos globais: 20/20 trechos amostrados encontrados. Isso nao comprova o endpoint autenticado em producao nem todas as letras.
- APK release compilado, pacote br.com.cifraband.cifra_band, versionCode 23, versionName 1.5.5; assinatura igual a da distribuicao beta anterior.
- Dependencias backend: 9 alertas moderados preexistentes na cadeia Firebase/Google; nao houve atualizacao forcada de dependencias maiores.

## Reproducao

Executar `dart run tool/benchmark_music_search.dart` na raiz. Sao 50 buscas sequenciais com intervalo entre consultas, e os resultados ficam em `build/search-benchmark.json`. Resultados de provedores externos podem mudar.

Detalhes de arquitetura e referencias: [Melhoria da pesquisa](MELHORIA_PESQUISA.md).

## Publicacao confirmada

- GitHub: release publica v1.5.5; download HTTP 200; APK de 67281310 bytes.
- SHA-256 do APK local e asset GitHub: 0c9def7a3eb1f2da1722388250d8801cc57892d6eb40246c5d656610afc75d65.
- Render /app-version conferido em 2026-09-12T14:22:44Z: latestVersion 1.5.5, latestBuild 23, minimumBuild 21, updateRequired false, URL direta do asset correto.
- Em producao, /catalog-search e /devices/register retornaram 401 sem token, como esperado. O caminho autenticado de catalog-search nao foi exercitado em producao nesta verificacao.
- Firestore system_jobs/app_update_push mostrou build 23, lease liberada e cursor nulo apos o processamento. Isso nao confirma entrega fisica de notificacao em cada aparelho.
- Nao houve instalacao por USB. A verificacao de instalacao e uso no celular do usuario continua pendente.
