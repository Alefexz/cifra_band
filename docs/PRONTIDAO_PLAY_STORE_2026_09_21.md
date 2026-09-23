# Cifra Band: ministerio e prontidao para Google Play

Data: 21/09/2026. Meta informada: 30/09/2026.

## Decisao

**NAO liberar a versao atual para producao na Google Play.**

O responsavel informou que ainda nao tem licencas para as letras/cifras de
terceiros e ainda nao criou a conta de desenvolvedor. Os testes de engenharia
nao substituem essas pendencias. Aprovacao na loja tambem nao elimina risco
juridico. Este documento e uma triagem tecnica e de conformidade, nao um parecer
juridico ou garantia de ausencia de processo.

Nada foi publicado, nenhuma regra foi implantada em producao, nenhum APK/AAB foi
gerado nesta etapa e a versao continua 1.5.9+27. Preservadas as alteracoes locais
da estabilizacao anterior, detalhadas em ESTABILIZACAO_ETAPA_1.md.

## O que foi implementado localmente

1. Home do ministerio -> Central de ensaios -> culto -> aba ENSAIO.
2. Cultos proximos/anteriores, ordenados por data, com carregamento em lotes de
   30. Reutiliza os indices church_id/date ja declarados no projeto.
3. Repertorio aprovado com tom, orientacoes existentes e abertura da cifra.
4. Preparacao individual: ainda nao estudei, estudando, preparado, preciso de ajuda.
5. Observacao por musica compartilhada com o ministerio; nao e uma nota privada.
6. Visao de preparacao por integrante/funcao. O denominador considera a equipe
   escalada sem duplicar integrantes em duas funcoes e exclui recusas.
7. Alteracao musical (tom, capo, conteudo, BPM, referencia ou orientacao) invalida
   a confirmacao antiga. O app mostra "Revisar arranjo" ate a pessoa confirmar.
8. A escrita usa transacao e confere se a versao musical continua aprovada antes
   de salvar. Offline, a confirmacao nao e inventada: apresenta erro e preserva o texto.
9. Corrigido: salvar observacao nao marca automaticamente a musica como ensaiada.
   A observacao existente e preenchida ao abrir; o botao de preparacao nao a apaga.
10. Tratamento de erro na leitura da escala, antes sujeito a carregamento infinito.
11. Regras validam identidade, estados, revisao, tamanho e campos das preparacoes.
    Nem o lider pode se passar por outro integrante para confirmar preparacao.
12. Identificador vazio de ministerio nao concede acesso por coincidencia entre
    dois perfis sem ministerio.
13. Removido envio de e-mail e ID do ministerio como chaves extras do Crashlytics;
    valores persistidos de versoes anteriores sao limpos. Isso NAO apaga relatórios
    historicos nem anonimiza toda a telemetria; UID e diagnosticos ainda existem.
14. Preflight estatico tool/check_play_readiness.ps1 lista os bloqueios conhecidos
    e retorna codigo 1. Nao e uma certificacao automatica de publicacao.

### Limites deliberados

- A Central prepara o repertorio do culto. Nao foi criado calendario separado de
  encontros de ensaio, chat, upload de audio, sincronizacao de palco ou notificacoes
  novas em massa. Esses itens aumentariam o risco antes da estabilizacao.
- Membros do mesmo ministerio veem as preparacoes; somente o proprio autor as altera.
  Uma preparacao de quem nao esta escalado nao entra no percentual da equipe.
- Status antigo "ja ensaiei" continua armazenado, mas sem revisao comprovada pede
  nova confirmacao. Nao inferimos que a pessoa conhece o arranjo atualizado.
- O modelo legado identifica preparacao por titulo/artista. Duas versoes diferentes
  da mesma musica no mesmo culto compartilham a chave: so a revisao confirmada fica
  pronta; a outra pede revisao. Modelar ocorrencias independentes e evolucao futura.
- Subcolecoes de ensaio ainda nao possuem limpeza automatica quando o culto e
  excluido. Ficam inacessiveis pelas regras, mas exigem politica de retencao/limpeza.
- Regras novas devem acompanhar a futura versao do app. Clientes antigos podem
  falhar ao editar um status enriquecido com o novo campo preparation se produzirem
  valores contraditorios. Validar a estrategia de atualizacao minima no rollout.
- Nenhuma permissao de dono do SaaS foi concedida a administradores de ministerio.

## Validacoes

Evidencias em build/stabilization/08-ministry-readiness-* e 09-ministry-final-*;
ultima bateria em 10-play-readiness-final-* apos o teste adicional do editor.

- Flutter: **117 testes passaram** na bateria final (10-play-readiness-final).
- Firestore Emulator: 32 testes passaram, incluindo isolamento entre ministerios,
  anonimo, lider versus autor, saida do ministerio, estados invalidos e limites de payload.
- Backend Node: 23 testes passaram.
- 12 testes novos Flutter cobrem estados, revisoes, participantes, abrir cifra,
  observacoes, falha/repeticao de salvamento e layout responsivo.
- Capturas renderizadas e inspecionadas em 320x640 e 800x1000, fonte a 160%:
  build/ministry-readiness/rehearsal-320.png e rehearsal-800.png.
- Analise estatica completa final: zero erros e zero warnings, com 140 avisos
  informativos legados. Os arquivos novos e seu teste: "No issues found".
- git diff --check passou nos dois repositorios. Preflight Play executado e
  reprovado, como esperado, pela permissao de instalacao de APK e assinatura debug.
- A bateria inclui a estabilizacao anterior: capo, dados locais por conta, retencao
  offline, atualizacao obrigatoria, contatos/compartilhamento e trabalho em segundo plano.
- Testes usam conteudo sintetico, sem copiar letras de terceiros.

Nao foi validado nesta etapa: AAB final assinado, instalacao/atualizacao pela Play,
celular/tablet fisicos, emulador Android 16 KB, entrega real FCM, carga de producao,
perda de rede em aparelho, nem auditoria de seguranca independente. O emulador
Firestore nao comprova que os indices de producao estao prontos.

## Bloqueios para a loja

| Prioridade | Evidencia | O que precisa acontecer |
| --- | --- | --- |
| Bloqueador | Usuario sem licencas; busca/cache/offline reproduzem conteudo externo | Licenciar uso e redistribuicao ou lancar uma edicao limitada a conteudo proprio/autorizado e recursos de gestao. |
| Bloqueador | AndroidManifest.xml declara REQUEST_INSTALL_PACKAGES; atualizador baixa APK do GitHub | Separar edicao Play da distribuicao direta. Na Play usar mecanismo da loja, sem instalador externo nem bloqueio baseado em versao exclusiva do GitHub. |
| Bloqueador | android/app/build.gradle.kts assina release com debug | Configurar chave de upload protegida, Play App Signing e plano de migracao dos instalados. Nao trocar a assinatura da distribuicao atual sem esse plano. |
| Bloqueador | Nao localizado fluxo de exclusao de conta/dados nem politica publica integrada | Implementar solicitacao no app e recurso web funcional; definir e executar exclusao, inclusive subcolecoes, tokens, caches locais, dados compartilhados e retencoes justificadas. |
| Bloqueador | Cadastro e dados de usuarios; Firebase Auth/Firestore/FCM/Crashlytics/Analytics | Mapear coleta e finalidade, publicar politica verdadeira e preencher Data Safety de acordo com o comportamento real dos SDKs. |
| Bloqueador | Cifras importadas, observacoes e compartilhamento sao UGC | Termos aceitos antes da contribuicao, denuncia de conteudo/usuario e moderacao efetiva; bloqueio onde exigido pela modalidade de interacao. Feedback generico nao comprova cobertura integral. |
| Bloqueador de prazo | Conta Play ainda nao existe | Criar conta adequada, validar identidade e cumprir testes exigidos. |
| Gate tecnico | targetSdk herdado do Flutter instalado resolve para 36; NDK 28.2.13676358 | Confirmar no AAB final API alvo, permissoes mescladas, assinatura e compatibilidade 16 KB; configuracao local nao basta. |
| Gate operacional | Loja ainda nao configurada | Icone/nome, screenshots reais, classificacao etaria, publico-alvo, declaracao de anuncios, credencial de revisao sem privilegios de dono e pre-launch report. |
| Gate de qualidade | Historico de regressao de setlists e cifras | Testar busca -> cifra completa -> tom/capo -> salvar -> reabrir -> compartilhar -> offline -> logout/trocar conta em aparelhos reais. |

## Direitos autorais e LGPD

Nao ter cobranca e usar em igreja nao sao uma autorizacao geral para copiar letras,
arranjos, traducoes ou imagens. Uma sequencia isolada de nomes de acordes nao deve
ser confundida automaticamente com a protecao de uma letra ou arranjo completo.
O risco concreto aqui e reproduzir e distribuir o conjunto obtido de terceiros,
inclusive armazenado no servidor e offline. Dar credito ou linkar a origem nao
substitui permissao para esses usos. "Hino antigo" nao comprova dominio publico
da traducao, do arranjo e da edicao usados.

Solicitar orientacao de advogado brasileiro de propriedade intelectual e
protecao de dados antes da distribuicao. Separar permissao do site/fonte da dos
titulares da obra, bem como direitos sobre capas/fotos. Licenca de execucao em
culto nao deve ser presumida como licenca de distribuicao em aplicativo.

Vinculo identificavel com organizacao religiosa pode ser dado pessoal sensivel
pela LGPD. Definir base legal apropriada, transparencia, minimizacao, acesso,
retencao, exclusao e tratamento de menores com assessoria. Nao usar consentimento
generico como resposta automatica para todas as finalidades.

Uma eventual edicao "somente gestao" precisa efetivamente restringir as fontes,
cache e downloads nao autorizados em todos os caminhos pertinentes, nao apenas
esconder um botao na revisao. O beta fechado tambem nao dispensa direitos/politicas.

## Plano para 30 de setembro

1. Decidir conteudo: negociar licencas OU preparar edicao de gestao com material
   comprovadamente proprio/autorizado. Nenhum documento foi inventado nesta etapa.
2. Criar conta pessoal se publicar como pessoa fisica, ou de organizacao se houver
   organizacao real com documentos exigidos. Nao usar organizacao ficticia para
   contornar os requisitos de teste.
3. Fechar privacidade, exclusao de dados, termos/moderacao e estrategia de assinatura.
4. Separar canal Play/canal APK, gerar AAB e validar o artefato final em pista de teste.
5. Em conta pessoal nova, manter pelo menos 12 participantes inscritos continuamente
   durante 14 dias no teste fechado, depois solicitar acesso a producao. APK enviado
   por WhatsApp/GitHub nao conta como participacao nesse teste.
6. Hoje, 21/09, ate 30/09 sao nove dias. Mesmo com inicio imediato em 21/09, os 14
   dias so terminariam em 05/10, antes da analise de acesso e revisao do aplicativo.
   Sem conta e sem conformidade prontas, a data real sera posterior. Dia 30 pode ser
   meta de preparacao/inicio de testes se os bloqueios forem resolvidos, nao garantia.

## Proximas entregas de ministerio

| Entrega | Utilidade | Decisao |
| --- | --- | --- |
| Central de ensaios por culto | Preparacao e ajuda por musica | Implementada localmente nesta etapa. |
| Catalogo oficial com tags e estado aprendendo/pronto/arquivado | Reutilizar repertorio autorizado | Proxima evolucao, apos definir politica de conteudo. |
| Mudancas importantes com ciente | Evitar equipe ensaiar tom/repertorio antigo | Revisao musical local implementada; aviso e ciente da equipe ainda nao. |
| Encontro de ensaio com data e participantes proprios | Organizar ensaios separados do culto | Planejado, nao implementado. |
| Ordem completa do culto e transicoes | Conectar musica, leitura e pregacao | Posterior aos gates de estabilidade e loja. |
| Audio por instrumento e palco sincronizado | Recurso avancado de ensaio | Adiado: exige licencas, armazenamento, sincronizacao e testes adicionais. |

## Fontes oficiais consultadas em 21/09/2026

- IP da Play: https://support.google.com/googleplay/android-developer/answer/9888072?hl=en
- Testes de contas pessoais: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
- Tipo de conta: https://support.google.com/googleplay/android-developer/answer/13634885?hl=en
- Exclusao: https://support.google.com/googleplay/android-developer/answer/13327111?hl=en
- Dados: https://support.google.com/googleplay/android-developer/answer/10144311?hl=en-GB
- Permissoes/instalacao: https://support.google.com/googleplay/android-developer/answer/16558241?hl=en-GB
- UGC: https://support.google.com/googleplay/android-developer/answer/9876937?hl=en-GB
- API alvo: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en
- 16 KB: https://developer.android.com/guide/practices/page-sizes
- Direitos autorais, especialmente art. 29: https://www.planalto.gov.br/ccivil_03/leis/l9610.htm
- LGPD, especialmente art. 5, II: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm
- Referencia de produto: https://www.planningcenter.com/services

Planning Center confirma a utilidade de biblioteca de arranjos, tons e preparacao
por repertorio e apresenta integracoes com provedores licenciados. E referencia
de fluxo, nao autorizacao para importar o catalogo de outra plataforma.
