# Push de atualizacoes

## Fluxo

1. Flutter le o token FCM e PackageInfo e envia POST /devices/register autenticado. O servidor grava app_devices/{sha256(token)} com uid, build, plataforma e data do registro. Clientes nao podem ler ou escrever essa colecao diretamente.
2. Uma resposta bem-sucedida do Render aciona a verificacao em segundo plano, sem esperar o FCM para responder ao usuario.
3. system_jobs/app_update_push guarda uma trava temporaria, build da campanha, cursor e proxima verificacao. Isso evita varreduras simultaneas, inclusive em dois processos.
4. Cada pagina examina 100 aparelhos. Somente Android, build conhecido menor que latestBuild, token ativo e lastNotifiedBuild menor que latestBuild recebem o aviso. Paginas seguintes continuam automaticamente enquanto o processo estiver ativo; o cursor permite retomar depois de interrupcao.
5. Envios aceitos pelo FCM atualizam lastNotifiedBuild. Tokens invalidos sao desativados e falhas temporarias podem ser tentadas na proxima varredura. Uma nova versao reinicia a campanha.

## Frequencia e entrega

- Verificacao local no maximo uma vez por minuto; ciclo completo no maximo uma vez a cada 15 minutos para a mesma versao. Publicar uma versao nova permite iniciar imediatamente no proximo acesso.
- Nenhum cron pago ou servico que mantenha Render acordado. Sem acessos, o backend nao pode iniciar o envio por conta propria.
- Notification payload permite exibicao pelo Android com app fechado. Tag fixa substitui avisos de atualizacao na bandeja e TTL de 24 horas limita avisos antigos na fila.
- Com app visivel, a mensagem aciona a verificacao do popup em vez de outra notificacao local duplicada.
- FCM confirma aceitacao, nao leitura nem exibicao no celular. Permissao negada, falta de internet, forcar parada e restricoes do sistema podem impedir ou atrasar a entrega.
- Uma falha entre enviar ao FCM e gravar o recibo pode causar reenvio. Nao ha transacao atomica entre FCM e Firestore; a tag fixa reduz duplicacao visual.

## Transicao

A versao 1.5.4 informa build por token. Aparelhos anteriores precisam instalar e abrir essa versao uma vez. Nao se infere a versao de todos os aparelhos a partir da conta ou de um ticket. Nenhum push de teste com atualizacao ficticia e enviado aos usuarios.

O registro e atualizado ao entrar, retomar o app e renovar token; o processo local evita registros repetidos por seis horas para o mesmo usuario/token/build. Falhas de rede tentam novamente com esperas de seis e quinze segundos, sem bloquear a interface.

## Validacao

Testes com emulador Firestore e FCM simulado: filtragem, reinicio, concorrencia, aparelho atualizado, token invalido, falha temporaria e paginacao de 101 aparelhos. Os testes nao comprovam entrega em um celular fisico fechado; isso exige um aparelho registrado numa versao anterior a uma futura versao real.

Referencias oficiais: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages e https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan

## Publicacao verificada - 2026-09-11

- GitHub: release publica v1.5.4, APK build 22, download HTTP 200 e tamanho 67281214 bytes.
- SHA-256 do APK: 998d0c104fc71ef7184c847cb295199cefe5d2d46e33d9770a6111b4facf68d2.
- Assinatura igual a da distribuicao beta anterior, permitindo atualizar sem desinstalar.
- Render /app-version: latestVersion 1.5.4, latestBuild 22, minimumBuild 21, updateRequired false e link direto do APK da release.
- Firestore system_jobs/app_update_push: build 22, verificacao concluida, cursor vazio e trava liberada.
- POST /devices/register sem autenticacao retorna HTTP 401.
- Validacao automatizada: 22 testes Flutter, 18 testes Firestore/worker e 8 testes Node aprovados; analise dos arquivos Dart alterados sem problemas.
- Entrega de push em celular fisico fechado ainda nao comprovada. Validar numa proxima release real, com aparelho registrado na 1.5.4, sem enviar atualizacao ficticia aos usuarios.
