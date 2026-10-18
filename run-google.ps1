param([string]$Device = '')
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'config/google.local.json'
if (-not (Test-Path -LiteralPath $configPath)) {
  throw 'Firebase configuration is missing. Add config/google.local.json first.'
}
$configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not $configuration.FIREBASE_PROJECT_ID -or -not $configuration.FIREBASE_ANDROID_APP_ID) {
  throw 'Firebase Android configuration is incomplete.'
}
if ($Device -eq 'chrome' -and -not $configuration.FIREBASE_WEB_APP_ID) {
  throw 'Register a Firebase web app before running the Google-connected browser version.'
}
$env:PUB_CACHE = 'D:\pub-cache'
Push-Location $PSScriptRoot
try {
  $deviceArguments = if ($Device) { @('-d', $Device) } else { @() }
  & flutter run @deviceArguments "--dart-define-from-file=$configPath"
  if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE." }
} finally {
  Pop-Location
}
