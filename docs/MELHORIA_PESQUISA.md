# Pesquisa por relevancia - 1.5.5 - 2026-09-12

## Diagnostico

SearchScreen fazia uma busca de 50 faixas na Apple e preservava a ordem recebida. O artista da primeira faixa virava o perfil destacado automaticamente. Duas consultas adicionais carregavam musicas e albuns desse artista antes de liberar os resultados. A aba Musicas exibia o perfil e ate 25 faixas do artista antes das correspondencias da consulta. Por isso uma musica encontrada podia ficar varias telas abaixo de resultados sem relacao.

O debounce invalidava respostas somente quando a proxima busca comecava. O tratamento de erro nao verificava o identificador da consulta. Busca sem resultados mostrava o conteudo de descoberta, misturando sugestoes com resultados reais.

## Implementacao

- MusicSearchRanking classifica titulo exato, titulo com qualificadores, frase e correspondencia das palavras em titulo/artista. O titulo continua tendo prioridade quando a consulta inclui artista.
- Normaliza acentos, caixa, espacos, apostrofos, "minha alma" / "minh'alma" e "por que" / "porque".
- Todas as palavras significativas da consulta precisam corresponder. Prefixos com pelo menos quatro letras sao aceitos. Numeros de hino exigem correspondencia exata; nao sao descartados para preencher a lista.
- Duplicatas de mesmo titulo/artista com sufixos ao vivo/live/remaster sao agrupadas. Medleys e subtitulos significativos permanecem distintos. Playback, karaoke e instrumental so entram quando solicitados.
- A aba Musicas mostra resultados primeiro. Perfil no topo apenas quando o nome do artista corresponde a consulta. Perfil relacionado fica depois das faixas; o app nao atribui a um hino local o artista de outra gravacao.
- Artistas e Albuns preservados, com carregamento sob demanda e erro isolado. A listagem nao e rotulada como ranking real de popularidade.
- MusicSearchService tem cliente HTTP injetavel, timeout, validacao de resposta e cache de cinco minutos limitado a 30 consultas por instancia.
- Respostas e erros antigos sao ignorados imediatamente ao digitar. O mesmo cuidado vale para troca entre abas.
- Resultado vazio e falha de rede sao estados distintos; nao sao apresentados como prova de que a cifra nao existe.

## Harpa e limites

Foi incluido um cadastro de metadados verificado para Porque Ele Vive, Harpa Crista, numero 545, com alias curto "Deus enviou". As consultas "por que ele vive 545" e "545 deus enviou" colocam esse registro primeiro. O clique usa o titulo canonico e artista Harpa Crista no fluxo existente de busca da cifra. Nao armazena a letra nesta tabela e nao pula validacao do conteudo pelo backend.

Este cadastro inicial NAO cobre todos os hinos. A busca agrega Deezer, Apple e o indice do banco global. Nao oferece correcao arbitraria de erros ortograficos nem garante encontrar qualquer musica. Sem numero, diferentes gravacoes do mesmo titulo podem continuar aparecendo, com seus artistas identificados.

As regras Firestore, transposicao e salvamento de setlists nao foram alterados. O backend ganhou um endpoint autenticado de busca no banco global e a release 1.5.5, build 23, mantendo minimumBuild 21. Ela e opcional para quem ja instalou as correcoes anteriores.

## Busca hibrida

- Deezer e Apple sao consultados de forma independente; o primeiro resultado util e mostrado sem esperar todas as fontes. Erro numa fonte permite usar as demais.
- Fuzzy 0.5.2, port de Fuse.js, permite erros pequenos em palavras com quatro ou mais letras, no maximo uma alteracao por palavra e uma ou duas palavras por consulta. Numeros nao usam aproximacao. Resultados aproximados sao identificados na tela e ficam abaixo de correspondencias exatas.
- Identificadores Deezer usam prefixo proprio, impedindo colisao com IDs Apple. Perfis, albuns e faixas de albuns respeitam o provedor original.
- GET /catalog-search?q=... exige Firebase ID token, consulta de 2 a 120 caracteres e limita 30 chamadas por minuto/usuario. Nao aceita colecao, UID de outra pessoa ou URL arbitraria.
- MiniSearch 7.2.0 indexa somente global_cifras com letra e acordes considerados utilizaveis. Nenhuma biblioteca privada de igreja, ticket ou perfil entra no indice.
- O indice cobre ate 1000 documentos, com ate 40000 caracteres de cada conteudo, atualiza no maximo uma vez por hora por processo e agrupa carregamentos concorrentes. Falhas usam o indice anterior e tem intervalo de nova tentativa. Uma inicializacao fria requer nova leitura; isso usa a quota normal do Firestore, nao um servico de busca pago.
- Em 2026-09-12 o banco tinha 259 cifras, todas indexadas dentro desse limite. Trechos: exige frase correspondente e ao menos tres palavras significativas. O endpoint devolve metadados, nao a letra inteira. Vinte trechos extraidos de cifras reais foram localizados em teste local com copia somente de leitura do banco.
- O limite de 1000 e a cobertura de letras precisam ser revistos ao escalar. Esta implementacao nao e um indice da internet nem usa as letras licenciadas do Deezer.
- Auditoria npm ainda aponta nove alertas moderados em dependencias anteriores (Firebase/Google, uuid e qs); MiniSearch nao aparece nos alertas. Nao foi feita migracao major do Firebase Admin nesta entrega.

## Evidencias

- Testes de ranking, fontes independentes, cache, aproximacao, trechos, IDs de provedores, artistas, albuns e telas, alem da suite existente de cifras. Resultado consolidado em TESTE_50_MUSICAS_1_5_5.md.
- Testes cobrem os dois exemplos enviados, numero divergente, titulo/artista, variantes, cache, erro HTTP, resposta antiga, navegacao por artista, vazio e viewport 320x700 com texto 1,5x.
- Captura da tela Flutter em build/search-preview.png usa dados controlados, sem fotos de artistas. Nao e captura do celular do usuario.
- Consulta real via `dart run tool/check_music_search.dart`: 545 primeiro como Harpa Crista; Bondade de Deus + Isaias Saad prioriza titulo exato; Fernandinho preserva perfil; Galileu retorna faixas correspondentes.
- Amostra local: consultas remotas de aproximadamente 0,34 a 2,58 segundos. Consulta repetida equivalente ao hino, reutilizando cache, 8 a 9 ms. Sao observacoes deste teste, nao promessa de latencia em outro aparelho/rede.

## Fontes

- [Apple: parametros e cache da Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html)
- [Algolia: criterios de relevancia textual](https://www.algolia.com/doc/guides/managing-results/relevance-overview/in-depth/ranking-criteria)
- [Cifra Club: titulo, artista e numero do hino 545](https://www.cifraclub.com.br/harpa-crista/porque-ele-vive/)
- [Cifra Club: como encontrar uma cifra](https://suporte.cifraclub.com.br/pt-BR/support/solutions/articles/64000260568-como-encontrar-uma-cifra-no-app-do-cifra-club-)
- [Deezer: busca por letras](https://newsroom-deezer.com/2021/01/find-my-song-deezer-introduces-search-by-lyrics-2/)
- [MiniSearch: indice, fuzzy e pesos](https://lucaong.github.io/minisearch/)
- [Fuzzy para Dart](https://github.com/comigor/fuzzy)

A documentacao da API de desenvolvedores do Deezer nao estava acessivel na pesquisa. Os endpoints publicos de catalogo, artistas e albuns foram verificados por requisicoes e testes. A empresa nao publica nesse material o algoritmo completo de ordenacao; nao alegamos reproduzi-lo.

Os principios de relevancia foram adaptados localmente; nao foi contratado Algolia nem outro servico pago.
