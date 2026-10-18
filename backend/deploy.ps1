param(
  [Parameter(Mandatory = $true)][string]$ProjectId,
  [string]$Region = 'asia-southeast2',
  [string]$GeminiModel = 'gemini-3.8-flash',
  [string]$GeminiLocation = 'global',
  [string[]]$AllowedOrigins = @()
)
$ErrorActionPreference = 'Stop'
$cloudCli = Join-Path $env:LOCALAPPDATA 'Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd'
if (-not (Test-Path -LiteralPath $cloudCli)) {
  $cloudCli = (Get-Command gcloud.cmd -ErrorAction Stop).Source
}
function Invoke-Gcloud {
  & $cloudCli @args
  if ($LASTEXITCODE -ne 0) { throw "Google Cloud command failed (exit $LASTEXITCODE). Deployment stopped." }
}
if ($ProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$') { throw 'Invalid Google Cloud project ID.' }
foreach ($origin in $AllowedOrigins) {
  if ($origin -notmatch '^https?://[^/|,]+$') { throw "Invalid browser origin: $origin" }
}
$service = 'warungpilot-api'
$sa = "$service@$ProjectId.iam.gserviceaccount.com"
Write-Host "Preparing project $ProjectId"
Invoke-Gcloud services enable run.googleapis.com aiplatform.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com identitytoolkit.googleapis.com --project $ProjectId --quiet
$exists = Invoke-Gcloud iam service-accounts list --project $ProjectId --filter="email:$sa" --format='value(email)' --quiet
if (-not $exists) {
  Invoke-Gcloud iam service-accounts create $service --project $ProjectId --display-name 'Retailee API' --quiet
}
Invoke-Gcloud projects add-iam-policy-binding $ProjectId --member "serviceAccount:$sa" --role 'roles/aiplatform.user' --condition=None --quiet | Out-Null
$origins = $AllowedOrigins -join ','
$environmentPath = Join-Path ([System.IO.Path]::GetTempPath()) ("retailee-cloudrun-" + [guid]::NewGuid().ToString('N') + '.json')
@{
  GOOGLE_CLOUD_PROJECT = $ProjectId
  FIREBASE_PROJECT_ID = $ProjectId
  GEMINI_MODEL = $GeminiModel
  GEMINI_LOCATION = $GeminiLocation
  ALLOWED_ORIGINS = $origins
} | ConvertTo-Json | Set-Content -LiteralPath $environmentPath -Encoding utf8
Write-Host "Deploying $service to $Region"
try {
  Invoke-Gcloud run deploy $service --project $ProjectId --source "$PSScriptRoot" --region $Region --service-account $sa --allow-unauthenticated --memory 512Mi --min-instances 0 --max-instances 3 --timeout 60 --env-vars-file $environmentPath --quiet
} finally {
  Remove-Item -LiteralPath $environmentPath -ErrorAction SilentlyContinue
}
$url = Invoke-Gcloud run services describe $service --project $ProjectId --region $Region --format='value(status.url)' --quiet
$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config/google.local.json'
if (Test-Path -LiteralPath $configPath) {
  $configuration = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  if ($configuration.FIREBASE_PROJECT_ID -ne $ProjectId) { throw 'App configuration project mismatch.' }
  $configuration.AI_ENDPOINT = [string]$url
  $configuration | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8
}
Write-Host "AI_ENDPOINT = $url"
Write-Host 'App configuration updated. A deployment does not verify a complete photo scan.'
