param(
  [Parameter(Mandatory = $true)][string]$ProjectId,
  [Parameter(Mandatory = $true)][string]$Bucket
)
$ErrorActionPreference = 'Stop'
if ($ProjectId -ne 'hackacthon-7ec2e' -or $Bucket -ne 'hackacthon-7ec2e.firebasestorage.app') {
  throw 'This publishing script is scoped to the configured Retailee project and bucket.'
}
$cloudCli = Join-Path $env:LOCALAPPDATA 'Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd'
$accessToken = (& $cloudCli auth print-access-token --quiet) -join ''
if ($LASTEXITCODE -ne 0 -or -not $accessToken) { throw 'Google Cloud login is unavailable.' }
$headers = @{ Authorization = "Bearer $accessToken"; 'x-goog-user-project' = $ProjectId }
$base = "https://firebaserules.googleapis.com/v1/projects/$ProjectId"
$releaseName = "projects/$ProjectId/releases/firebase.storage/$Bucket"
$releaseUrl = "https://firebaserules.googleapis.com/v1/$releaseName"
$source = Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'storage.rules') -Raw
try {
  $current = $null
  try {
    $current = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -Method Get
  } catch {
    if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
  }
  if ($current) {
    $previous = Invoke-RestMethod -Uri "https://firebaserules.googleapis.com/v1/$($current.rulesetName)" -Headers $headers -Method Get
    $backup = @{ release = $current; ruleset = $previous }
    $backup | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'qa/storage-rules-before.json') -Encoding utf8
  }
  $body = @{ source = @{ files = @(@{ name = 'storage.rules'; content = $source }) } } | ConvertTo-Json -Depth 6
  $ruleset = Invoke-RestMethod -Uri "$base/rulesets" -Headers $headers -Method Post -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
  $release = @{ name = $releaseName; rulesetName = $ruleset.name }
  if ($current) {
    $body = @{ release = $release; updateMask = 'rulesetName' } | ConvertTo-Json -Depth 5
    $result = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -Method Patch -ContentType 'application/json' -Body $body
  } else {
    $body = $release | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$base/releases" -Headers $headers -Method Post -ContentType 'application/json' -Body $body
  }
  $published = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -Method Get
  if ($published.rulesetName -ne $ruleset.name) { throw 'The published ruleset does not match the intended ruleset.' }
  [pscustomobject]@{ Bucket = $Bucket; RulesPublished = $true; Ruleset = $published.rulesetName; UpdatedAt = $published.updateTime } | ConvertTo-Json
} finally {
  $headers = $null
  $accessToken = $null
}
