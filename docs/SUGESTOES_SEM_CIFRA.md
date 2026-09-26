# Sugestoes de louvor sem cifra

Versao preparada: 1.6.1+29, canal direto de testes da igreja.

## Fluxo

- Escala -> Sugerir louvor -> buscar nome/artista no catalogo existente, ou informar manualmente.
- Confirmar nome/artista. Nao existe campo para colar link e nao e necessario buscar cifra.
- A sugestao salva kind=listening, identidade do autor validada pelo servidor e votos iniciais. Nao salva conteudo ou tom ficticio.
- Ao abrir uma sugestao, o painel consulta cifra, YouTube e Spotify independentemente. Links confirmados abrem a gravacao no aplicativo externo. A cifra completa abre no leitor existente.
- Falhas de um provedor nao bloqueiam os demais. Existe tentativa manual e limites de tempo.
- YouTube usa descoberta publica e confirmacao por oEmbed. Disponibilidade depende do provedor de busca, sem garantia de encontrar toda musica.
- Spotify usa API oficial quando SPOTIFY_CLIENT_ID e SPOTIFY_CLIENT_SECRET estao configurados no servidor. Sem credenciais existe tentativa por referencias publicas, mas ela nao e confiavel. O painel informa servico nao configurado quando essa tentativa nao confirma um link.
- Credenciais nao sao enviadas ao app nem incluidas no Git. Resultado nao confirmado nao significa que a musica nao existe.
- Links enviados aceitos: HTTPS em dominios especificos de YouTube, Spotify, Deezer, Apple Music e SoundCloud. Dominios parecidos, credenciais na URL e protocolos inseguros sao recusados. O servidor nao baixa esses links.
- Continua disponivel buscar uma cifra antes de sugerir. Setlists normais continuam exigindo cifra completa.
- Repertorio de ensaio abre as mesmas opcoes de audio quando nao tem cifra. Downloads offline incluem apenas cifras completas, nao audio dos provedores.

## Compatibilidade e publicacao

Publicar as alteracoes de functions antes de distribuir o novo APK. A API anterior rejeita sugestoes sem content. Clientes antigos nao conhecem a acao de ouvir: nao anunciar esta funcionalidade como disponivel neles.

POST /members/song-links exige autenticacao, mesmo ministerio e musica registrada na escala. Cache de referencias confirmadas por seis horas, ate 300 entradas, deduplicacao de pedidos e no maximo quatro consultas externas simultaneas.

Nao foram alteradas regras de acesso Firestore. Continua restrito a integrante escalado ou administrador do mesmo ministerio. O servidor nao aceita autoria/votos forjados. Sugestoes legadas com cifra continuam aceitas.

## Validacoes

- Bateria final: build/stabilization/release-161-*.
- Flutter: 129 aprovados, 1 ignorado exclusivo Play. Firebase Auth/Firestore emulados: 37 aprovados. Node: 34 aprovados.
- Analise estatica: zero erros ou avisos; 144 informacoes de estilo. O comando analyze retorna 1 por essas informacoes, nao foi tratado como analise totalmente limpa.
- Consulta real: Ah Jesus / Julliany Souza encontrou https://www.youtube.com/watch?v=ldK43s9UyQI em 1528 ms. Spotify retornou configuration_required neste ambiente sem credenciais. Isso nao valida todas as musicas.
- Mocks verificam contratos e falhas, nao disponibilidade dos provedores reais.
- Teste de tela estreita com fonte grande e teclado; erro de envio preserva os campos.
- Abertura real nos aplicativos Spotify/YouTube em aparelho fisico ainda precisa de smoke test. Nao foram enviadas sugestoes a escalas reais durante os testes.

Referencias: https://developer.spotify.com/documentation/web-api/tutorials/client-credentials-flow e https://developer.spotify.com/documentation/web-api/reference/search
