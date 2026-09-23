param([Parameter(Mandatory=$true)][string]$Item)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
New-Item -ItemType Directory -Force -Path 'build/stabilization' | Out-Null
$results = [ordered]@{}
& flutter analyze --no-pub *> "build/stabilization/$Item-analyze.txt"
$results.analyze = $LASTEXITCODE
& flutter test --no-pub --reporter expanded *> "build/stabilization/$Item-flutter.txt"
$results.flutter = $LASTEXITCODE
& firebase emulators:exec --config firebase.emulators.json --only firestore,auth --project demo-cifra-band "npm --prefix test/firestore test" *> "build/stabilization/$Item-rules.txt"
$results.rules = $LASTEXITCODE
Push-Location functions
$tests = @('test-member-actions.js', 'test-content.js', 'test-catalog-search.js', 'test-update-version.js')
if (Test-Path 'test-youtube-background.js') { $tests += 'test-youtube-background.js' }
if (Test-Path 'test-distribution.js') { $tests += 'test-distribution.js' }
if (Test-Path 'test-account-deletion.js') { $tests += 'test-account-deletion.js' }
& node --test @tests *> "$root/build/stabilization/$Item-node.txt"
$results.node = $LASTEXITCODE
Pop-Location
$results | ConvertTo-Json
if (Select-String -Path "build/stabilization/$Item-analyze.txt" -Pattern '^\s*(error|warning) -' -Quiet) { exit 1 }
if ($results.flutter -ne 0 -or $results.rules -ne 0 -or $results.node -ne 0) { exit 1 }
