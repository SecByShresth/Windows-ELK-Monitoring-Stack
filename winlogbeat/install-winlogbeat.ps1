<#
Install and configure Winlogbeat (latest version, no SSL) on Windows.
Run as Administrator.
#>

param(
    [string]$WinlogbeatVersion = "8.15.1",
    [string]$InstallDir = "C:\Program Files\winlogbeat"
)

$ErrorActionPreference = 'Stop'

# 1) Ensure installation directory exists
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 2) Download Winlogbeat ZIP
$zip = "$env:TEMP\winlogbeat.zip"
$url = "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-$WinlogbeatVersion-windows-x86_64.zip"

Write-Host "Downloading Winlogbeat version $WinlogbeatVersion..."
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

# 3) Extract ZIP
Write-Host "Extracting Winlogbeat..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, "$env:TEMP\winlogbeat")
} catch {
    Write-Warning "Extraction skipped or folder already exists: $($_.Exception.Message)"
}

# 4) Copy distribution to installation folder
$extractedRoot = Get-ChildItem "$env:TEMP\winlogbeat" | Where-Object { $_.PSIsContainer } | Select-Object -First 1
Write-Host "Copying Winlogbeat to $InstallDir..."
Copy-Item -Path "$($extractedRoot.FullName)\*" -Destination $InstallDir -Recurse -Force

# 5) Copy template configuration (no SSL)
$template = Join-Path $PSScriptRoot 'winlogbeat.template.yml'
$destConfig = Join-Path $InstallDir 'winlogbeat.yml'
if (Test-Path $template) {
    Copy-Item -Path $template -Destination $destConfig -Force
    Write-Host "Copied winlogbeat.yml configuration."
} else {
    Write-Warning "Template config not found at $template. Ensure it exists."
}

# 6) Register Winlogbeat service
Set-Location $InstallDir
$serviceScript = Join-Path $InstallDir 'install-service-winlogbeat.ps1'
if (Test-Path $serviceScript) {
    Write-Host "Registering Winlogbeat service..."
    & $serviceScript
    Start-Sleep -Seconds 2
    Write-Host "Starting Winlogbeat service..."
    Start-Service winlogbeat
    Write-Host "Winlogbeat is now running."
} else {
    Write-Warning "Service installation script not found. You may need to run it manually."
}

Write-Host "Winlogbeat installation complete."
Write-Host "Verify logs in C:\Program Files\winlogbeat\logs and ensure it is sending events to Logstash."
