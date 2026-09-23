$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
[xml]$manifest = Get-Content -LiteralPath (Join-Path $root 'android/app/src/main/AndroidManifest.xml') -Raw
$gradle = Get-Content -LiteralPath (Join-Path $root 'android/app/build.gradle.kts') -Raw
$android = 'http://schemas.android.com/apk/res/android'
$permissions = @($manifest.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $android) })
$blockers = [System.Collections.Generic.List[string]]::new()
if ($permissions -contains 'android.permission.REQUEST_INSTALL_PACKAGES') {
    $blockers.Add('Main manifest permits APK installation. Separate Play distribution from the sideload updater.')
}
if ($gradle -notmatch 'create\("playUpload"\)' -or $gradle -notmatch 'Play release signing is not configured') {
    $blockers.Add('Play upload signing guard is missing. Direct legacy signing is intentionally separate.')
}
$manual = @(
    'Rights to lyrics, charts, artwork, translations, arrangements and offline redistribution.',
    'Published privacy policy, Data Safety and real account/data deletion in app and on the web.',
    'Terms acceptance and content/user reporting with an operational moderation process.',
    'Developer identity verification; closed testing requirements for a new personal account.',
    'Final AAB: target API requirement, merged permissions, signature and native 16 KB compatibility.',
    'Physical phone/tablet smoke tests, offline/account switching, notifications and Play track update.'
)
[ordered]@{
    technicalPreflightPassed = ($blockers.Count -eq 0)
    publicationDecision = $(if ($blockers.Count -gt 0) { 'blocked' } else { 'manual_review_required' })
    scope = 'Static preflight only. Passing automated tests is not legal or Play approval.'
    technicalBlockers = @($blockers)
    requiredManualEvidence = $manual
} | ConvertTo-Json -Depth 4
# A zero exit status means only that these static checks passed, not Play approval.
if ($blockers.Count -gt 0) { exit 1 }
exit 0
