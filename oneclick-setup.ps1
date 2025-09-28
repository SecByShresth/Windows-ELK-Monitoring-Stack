<#
One-click setup for ELK + Grafana on Windows (HTTP, latest images).
Run as Administrator in repo root:
.\oneclick-setup.ps1
#>

$ErrorActionPreference = 'Stop'

# Generate random string
function RandStr($len=20) {
    $bytes = New-Object 'Byte[]' $len
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [System.Convert]::ToBase64String($bytes) -replace '[^a-zA-Z0-9]', 'A' | Select-Object -First 1
}

# 1) Create .env if missing
if (-not (Test-Path .env)) {
    if (Test-Path .env.example) {
        Copy-Item .env.example .env
        $content = Get-Content .env
        $content = $content -replace 'changeme_grafana', (RandStr 16)
        $content | Set-Content .env
        Write-Host '.env generated with randomized passwords.'
    } else {
        Write-Error '.env.example not found. Cannot create .env.'
        exit 1
    }
} else {
    Write-Host '.env already exists — using existing file.'
}

# 2) Check Docker
try {
    docker version > $null 2>&1
} catch {
    Write-Error 'Docker not available. Please ensure Docker Desktop is installed and running (WSL2).'
    exit 1
}

# 3) Start Docker Compose
Write-Host 'Starting Docker Compose...'
docker compose up -d

# 4) Wait for Elasticsearch
Write-Host 'Waiting for Elasticsearch to be responsive (1-3 minutes)...'
$esReady = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri 'http://localhost:9200/_cluster/health' -Method GET -TimeoutSec 5
        if ($resp.status) {
            Write-Host "Elasticsearch status: $($resp.status)"
            $esReady = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 5
    }
}
if (-not $esReady) {
    Write-Warning 'Elasticsearch did not become ready in time. Check docker logs.'
}

# 5) Wait for Kibana
Write-Host 'Waiting for Kibana...'
$kReady = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $k = Invoke-RestMethod -Uri 'http://localhost:5601/api/status' -Method GET -TimeoutSec 5
        if ($k.status.overall.state -in @('green','yellow')) {
            $kReady = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 5
    }
}

if ($kReady) {
    Write-Host 'Kibana ready.'
} else {
    Write-Warning 'Kibana did not become ready after wait.'
}

# 6) Final instructions
Write-Host ''
Write-Host '===== SETUP COMPLETE (basic) ====='
Write-Host 'Kibana: http://localhost:5601'
Write-Host 'Grafana: http://localhost:3000 (admin password in .env)'
Write-Host 'Elasticsearch: http://localhost:9200'
Write-Host ''
Write-Host 'To install Winlogbeat on this host (recommended): run (as Administrator):'
Write-Host '.\winlogbeat\install-winlogbeat.ps1'
Write-Host ''
Write-Host 'NOTE: This stack uses plain HTTP (no certificates) for local testing.'
Write-Host '=================================='
