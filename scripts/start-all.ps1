param(
  [string]$ComposeFile = "docker-compose.yml"
)
Set-Location (Join-Path $PSScriptRoot "..")
Write-Host "Starting docker compose..."
docker compose -f $ComposeFile up -d
