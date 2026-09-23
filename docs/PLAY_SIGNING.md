# Assinatura e canais Android

Nenhuma chave de upload foi criada pelo Codex. Nada foi publicado. Play App
Signing precisa ser ativado por voce na Play Console; codigo local nao ativa
esse servico.

## Canais

- `direct`: padrao do pubspec. Mesmo applicationId, assinatura debug legada e
  atualizador por APK usados pelo beta. A chave NAO foi trocada.
- `play`: mesmo applicationId por enquanto; Google Play In-App Updates, sem
  instalador externo. Nao recebe pushes referentes a APK do canal direto quando
  o backend atualizado estiver implantado e o dispositivo registrar seu canal.
- As edicoes nao podem coexistir no mesmo aparelho com esse applicationId.
  A chave de upload NAO e necessariamente a chave que assina os APKs da Play.
  Nao presuma que uma instalacao beta aceita sobreinstalacao da Play. Decidir a
  migracao (ou outro applicationId/Firebase app) antes de distribuir pela loja.

## Gerar e guardar sua chave (execute voce mesmo)

1. Crie uma pasta privada FORA do repositorio, por exemplo
   `C:\Users\nioti\cifraband-signing`. Garanta acesso apenas a sua conta.
2. Execute em PowerShell (as senhas serao solicitadas interativamente):

```powershell
& 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' -genkeypair -v -keystore 'C:\Users\nioti\cifraband-signing\play-upload.jks' -alias play-upload -keyalg RSA -keysize 3072 -validity 10000 -storetype JKS
```

3. Use dados verdadeiros e senhas fortes. Nao envie a chave/senhas em chat, commit
   ou screenshot. Guarde duas copias criptografadas e as senhas em gerenciador.
4. Nessa mesma pasta privada, crie `play-signing.properties` com:

```properties
storeFile=C:/Users/nioti/cifraband-signing/play-upload.jks
storePassword=SUA_SENHA_DO_ARQUIVO
keyAlias=play-upload
keyPassword=SUA_SENHA_DA_CHAVE
```

5. Aponte o build para esse arquivo, apenas na sua sessao:

```powershell
$env:CIFRABAND_PLAY_KEY_PROPERTIES='C:\Users\nioti\cifraband-signing\play-signing.properties'
Remove-Item Env:ORG_GRADLE_PROJECT_allowUnsignedPlayTest -ErrorAction SilentlyContinue
Remove-Item Env:CIFRABAND_UNSIGNED_PLAY_TEST -ErrorAction SilentlyContinue
flutter build appbundle --flavor play --release
```

6. O AAB ficara em `build/app/outputs/bundle/playRelease/app-play-release.aab`.
   Sem chave configurada, esse comando deve falhar, nunca usar a chave debug.
7. Na criacao do aplicativo na Play Console, configure Play App Signing conforme
   a estrategia de migracao escolhida. O padrao de chave de assinatura gerenciada
   pelo Google e diferente da chave local de upload. Registre os certificados
   SHA-1/SHA-256 corretos no Firebase quando necessario.
8. Confira o certificado do AAB com `keytool -printcert -jarfile CAMINHO_DO_AAB`.
   Depois teste a instalacao/atualizacao pela pista interna da Play com conta
   autorizada. O fluxo Play Core nao pode ser comprovado so com um APK sideload.

## AAB de inspecao sem chave

```powershell
$env:CIFRABAND_UNSIGNED_PLAY_TEST='true'
flutter build appbundle --flavor play --release
Remove-Item Env:CIFRABAND_UNSIGNED_PLAY_TEST
```

Essa excecao e apenas para inspecao local. O artefato nao e publicavel e nao deve
ser anexado a release do GitHub nem enviado a usuarios. Nao foi criada chave
substituta para contornar sua decisao.

## Beta direto

```powershell
flutter build apk --flavor direct --release
```

Saida: `build/app/outputs/flutter-apk/app-direct-release.apk`. Comandos antigos
sem `--flavor` passam a selecionar `direct`; scripts que dependem literalmente
do nome `app-release.apk` precisam usar o novo nome. O comportamento do updater
e a assinatura permanecem os mesmos. Confirmar o certificado com `apksigner`
antes de qualquer distribuicao; nenhum release automatico foi alterado aqui.

Fontes: https://developer.android.com/studio/publish/app-signing
e https://developer.android.com/guide/playcore/in-app-updates/test
