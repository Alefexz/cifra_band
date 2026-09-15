# Atualizacao de instalacoes antigas

## Evidencia encontrada em 15/09/2026

O commit apontado pela tag v1.0.5 contem pubspec.yaml com version 1.0.0+1. Seu lib/main.dart nao importa nem chama AppUpdateService, e lib/core/services/app_update_service.dart ainda nao existe nessa arvore. O servico de push ja registra tokens em users.fcmTokens e exibe notificacoes, sem callback de atualizacao.

Portanto, uma instalacao desse codigo pode receber notificacao sem ter a funcionalidade de baixar/instalar outra versao. A etiqueta 1.0.0 relatada pelo usuario e compativel com esse caso, mas nao prova sozinha qual APK esta instalado no tablet.

O atualizador e o registro de build por aparelho foram adicionados depois. Mudar o manifesto no servidor nao injeta codigo nos APKs antigos. Tokens legados em users.fcmTokens tambem nao equivalem a aparelhos com versao registrada em app_devices; nao e seguro supor que todos os tokens de uma conta tenham a mesma versao.

## Recuperacao

1. No aparelho antigo, abrir o link direto do APK publicado e baixar.
2. Abrir o arquivo baixado e confirmar a atualizacao no instalador Android. Se solicitado, permitir instalacao por esse navegador apenas para o arquivo confiavel.
3. Nao desinstalar nem limpar os dados como primeira tentativa.
4. Abrir o app atualizado; versoes modernas consultam o manifesto e registram o build por aparelho autenticado.
5. Se o instalador recusar, coletar mensagem exata, modelo, Android, versionCode e assinatura do APK instalado antes de qualquer outra intervencao.

APK 1.5.9: https://github.com/Alefexz/cifra_band/releases/download/v1.5.9/cifra-band-1.5.9-build-27.apk

Pacote publicado: br.com.cifraband.cifra_band; minSdk 24; ABIs arm64-v8a, armeabi-v7a, x86_64. Assinatura preservada das versoes recentes. A assinatura do APK efetivamente instalado no tablet nao foi inspecionada.

O Android exige identidade de pacote/assinatura compativel para atualizar uma instalacao: https://developer.android.com/studio/publish/app-signing

## Limites do push

O worker atual avisa dispositivos registrados e habilitados, com build inferior ao publicado e que ainda nao foram avisados daquele build. O recebimento depende de token valido, permissao, rede e servicos do dispositivo. O push nao confirma instalacao e nao pode dispensar a confirmacao do instalador Android.

A publicacao 1.5.9 exige build 27 em clientes que implementam o atualizador. Nao torna retroativamente obrigatorio o update em um cliente sem esse codigo.
