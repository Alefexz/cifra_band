# Publicacao 1.5.8+26

14/09/2026 em Manaus; confirmacao em 15/09/2026 UTC.

- App: commit ad7bf24, tag v1.5.8.
- Backend: commit f34f736, publicado no Render.
- /app-version confirmado em 2026-09-15T03:12:46.581Z: latestVersion 1.5.8, latestBuild 26, minimumBuild 25, updateRequired false. Opcional para build 25; builds anteriores continuam abaixo do minimo.
- Release: https://github.com/Alefexz/cifra_band/releases/tag/v1.5.8
- APK: https://github.com/Alefexz/cifra_band/releases/download/v1.5.8/cifra-band-1.5.8-build-26.apk
- Tamanho: 67428662 bytes. GitHub confirmou tamanho e SHA-256; download publico HEAD retornou HTTP 200 com o tamanho esperado.
- SHA-256: c9837b6cbcee4e8a744cd0e4eff17611f6c4801ac597f0f381725e0371135ff1.
- Package br.com.cifraband.cifra_band; versionName 1.5.8; versionCode 26.
- Assinatura preservada: 9012b9d3b3f2f2d81305d1f55efc23ab2ad4adf3d09aa3e1d77f89f0f05f5d16. Identidade de assinatura do beta, sem migracao nesta publicacao.
- 85 testes Flutter, 28 testes de regras/push e 18 testes Node passaram.
- Analise dos seis arquivos Dart alterados: sem erros ou warnings; cinco infos de estilo de chaves no servico offline existente.
- Build release concluido. Aviso de fonte Cupertino no build; interface alterada usa Material Icons.
- Nenhuma alteracao nas regras Firestore ou migracao de documentos nesta versao.
- Sem instalacao por USB ou validacao em telefone fisico; nao foi verificado recebimento de push no aparelho.

## Fluxo publicado

Na cifra, + abre seletor de setlists proprias/compartilhadas e criacao de setlist. A versao exibida e preservada, inclusive tom e capo. Mesmo ID de versao nao e duplicado pelo novo seletor.

Dentro da setlist, tres pontos > Baixar / atualizar setlist offline verifica a lista no servidor, aproveita conteudo local completo e obtem o restante no banco. Documento com metadados mas sem conteudo consulta cache global/backend. Nao substitui uma copia completa anterior por uma lista parcialmente baixada.

Abrir copia offline fica no mesmo menu e os downloads tambem aparecem em Setlists Offline. A copia representa o momento do download; apos editar a setlist, atualize o download.

O topo da cifra foi reduzido, mantendo configuracoes de leitura, anotacoes e biblioteca oficial no menu de configuracoes.
