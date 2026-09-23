param(
    [string]$Aab = 'build/app/outputs/bundle/playRelease/app-play-release.aab',
    [string]$Bundletool = 'build/play-readiness/bundletool-1.18.3.jar'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$java = 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe'
$aabPath = (Resolve-Path -LiteralPath $Aab).Path
$toolPath = (Resolve-Path -LiteralPath $Bundletool).Path
$hash = (Get-FileHash -LiteralPath $aabPath -Algorithm SHA256).Hash
$output = Join-Path $root "build/play-readiness/$($hash.Substring(0,12))"
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $java -jar $toolPath validate "--bundle=$aabPath" > "$output/validation.txt"
if ($LASTEXITCODE -ne 0) { throw 'bundletool validation failed' }
& $java -jar $toolPath dump manifest "--bundle=$aabPath" --module=base > "$output/manifest.xml"
if ($LASTEXITCODE -ne 0) { throw 'Manifest extraction failed' }
& $java -jar $toolPath dump config "--bundle=$aabPath" > "$output/config.json"
if ($LASTEXITCODE -ne 0) { throw 'Config extraction failed' }
[xml]$manifest = Get-Content -LiteralPath "$output/manifest.xml" -Raw
$ns = 'http://schemas.android.com/apk/res/android'
$permissions = @($manifest.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $ns) })
$config = Get-Content -LiteralPath "$output/config.json" -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.IO.Compression.FileSystem
$extracted = Join-Path $output 'extracted'
if (!(Test-Path -LiteralPath $extracted)) { [System.IO.Compression.ZipFile]::ExtractToDirectory($aabPath, $extracted) }
& node tool/inspect_native_artifact.cjs $extracted play > "$output/native.json"
if ($LASTEXITCODE -ne 0) { throw "Native/channel inspection failed; see $output/native.json" }
$native = Get-Content -LiteralPath "$output/native.json" -Raw | ConvertFrom-Json
$zip = [System.IO.Compression.ZipFile]::OpenRead($aabPath)
try { $signed = @($zip.Entries | Where-Object { $_.FullName -match '^META-INF/.*\.(RSA|DSA|EC)$' }).Count -gt 0 } finally { $zip.Dispose() }
$result = [ordered]@{
    artifact = $aabPath; sha256 = $hash; bytes = (Get-Item -LiteralPath $aabPath).Length
    targetSdk = [int]$manifest.manifest.'uses-sdk'.GetAttribute('targetSdkVersion', $ns)
    minSdk = [int]$manifest.manifest.'uses-sdk'.GetAttribute('minSdkVersion', $ns)
    package = $manifest.manifest.package
    versionName = $manifest.manifest.GetAttribute('versionName', $ns)
    versionCode = $manifest.manifest.GetAttribute('versionCode', $ns)
    permissions = $permissions
    installPackagesPresent = $permissions -contains 'android.permission.REQUEST_INSTALL_PACKAGES'
    pageAlignment = $config.optimizations.uncompressNativeLibraries.alignment
    nativeLibraries = @($native.libraries).Count
    native64BitAlignmentPassed = !$native.failedAlignment
    channelMarkersPassed = $native.channelValid
    jarSignaturePresent = $signed
    publishable = $false
    evidenceDirectory = $output
    runtime16KBTest = 'not_run'
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath 'build/play-readiness/artifact-report.json'
$result | ConvertTo-Json -Depth 6
if ($result.targetSdk -ne 36 -or $result.installPackagesPresent -or $result.pageAlignment -ne 'PAGE_ALIGNMENT_16K') { exit 1 }
