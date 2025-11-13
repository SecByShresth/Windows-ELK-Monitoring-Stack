#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-Click ELK Stack + Winlogbeat Setup Automation
.DESCRIPTION
    Automates deployment of ELK Stack (Elasticsearch, Logstash, Kibana) with Grafana and Winlogbeat.
    Supports two modes:
    1. Full ELK Stack + Winlogbeat (Host Setup)
    2. Winlogbeat-only (Remote Agent)
.PARAMETER CleanInstall
    Performs a clean installation, removing existing setup
.EXAMPLE
    .\oneclick-setup.ps1 -CleanInstall
#>

param(
    [switch]$CleanInstall
)

# Configuration
$Script:BaseDir = "$PSScriptRoot\elk-stack"
$Script:LogFile = "$PSScriptRoot\setup.log"
$Script:EnvFile = "$Script:BaseDir\.env"
$Script:DockerComposeFile = "$Script:BaseDir\docker-compose.yml"
$Script:LogstashPipelineFile = "$Script:BaseDir\logstash\pipeline\winlogbeat.conf"
$Script:WinlogbeatConfigFile = "$Script:BaseDir\winlogbeat\winlogbeat.yml"
$Script:WinlogbeatInstallDir = "C:\Program Files\Winlogbeat"
$Script:WinlogbeatVersion = "8.15.1"

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $Script:LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-Success { Write-ColorOutput $args[0] "Green" }
function Write-Info { Write-ColorOutput $args[0] "Cyan" }
function Write-Warning { Write-ColorOutput $args[0] "Yellow" }
function Write-Error { Write-ColorOutput $args[0] "Red" }

# Generate random password
function New-RandomPassword {
    param([int]$Length = 16)
    # Use only alphanumeric characters to avoid shell escaping issues
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Check if Docker is running
function Test-DockerRunning {
    try {
        $null = docker ps 2>&1
        return $true
    } catch {
        return $false
    }
}

# Clean existing installation
function Remove-ExistingSetup {
    Write-Info "Cleaning existing setup..."
    
    # Stop and remove Docker containers
    if (Test-Path $Script:DockerComposeFile) {
        Push-Location $Script:BaseDir
        try {
            docker-compose down -v 2>&1 | Out-Null
            Write-Success "Docker containers stopped and removed"
        } catch {
            Write-Warning "Failed to stop containers: $_"
        }
        Pop-Location
    }
    
    # Remove Winlogbeat service
    $service = Get-Service -Name "winlogbeat" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Info "Removing Winlogbeat service..."
        Stop-Service -Name "winlogbeat" -Force -ErrorAction SilentlyContinue
        & sc.exe delete winlogbeat | Out-Null
        Write-Success "Winlogbeat service removed"
    }
    
    # Remove directories
    if (Test-Path $Script:BaseDir) {
        Write-Info "Removing base directory..."
        Remove-Item -Path $Script:BaseDir -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Success "Base directory removed"
    }
    
    if (Test-Path $Script:WinlogbeatInstallDir) {
        Write-Info "Removing Winlogbeat installation..."
        Remove-Item -Path $Script:WinlogbeatInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Winlogbeat installation removed"
    }
}

# Create directory structure
function New-DirectoryStructure {
    Write-Info "Creating directory structure..."
    
    $dirs = @(
        $Script:BaseDir,
        "$Script:BaseDir\elasticsearch\data",
        "$Script:BaseDir\logstash\pipeline",
        "$Script:BaseDir\kibana\config",
        "$Script:BaseDir\grafana\data",
        "$Script:BaseDir\winlogbeat"
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }
    
    # Set permissions on Elasticsearch data directory
    $esDataDir = "$Script:BaseDir\elasticsearch\data"
    try {
        $acl = Get-Acl $esDataDir
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl $esDataDir $acl
        Write-Success "Permissions set on Elasticsearch data directory"
    } catch {
        Write-Warning "Could not set permissions on Elasticsearch data directory: $_"
    }
    
    Write-Success "Directory structure created"
}

# Generate .env file
function New-EnvironmentFile {
    Write-Info "Generating .env file with secure credentials..."
    
    $elasticPassword = New-RandomPassword
    $kibanaPassword = New-RandomPassword
    $logstashPassword = New-RandomPassword
    $grafanaPassword = New-RandomPassword
    $winlogbeatPassword = New-RandomPassword
    
    $envContent = @"
# Elasticsearch Configuration
ELASTIC_VERSION=8.15.0
ELASTIC_PASSWORD=$elasticPassword
ELASTIC_USERNAME=elastic

# Kibana Configuration
KIBANA_PASSWORD=$kibanaPassword
KIBANA_USERNAME=kibana_system

# Logstash Configuration
LOGSTASH_PASSWORD=$logstashPassword
LOGSTASH_USERNAME=logstash_system

# Grafana Configuration
GRAFANA_VERSION=11.3.0
GRAFANA_PASSWORD=$grafanaPassword
GRAFANA_USERNAME=admin

# Winlogbeat Configuration
WINLOGBEAT_VERSION=$Script:WinlogbeatVersion
WINLOGBEAT_PASSWORD=$winlogbeatPassword
WINLOGBEAT_USERNAME=winlogbeat_writer

# Network Configuration
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=9200
LOGSTASH_PORT=5044
KIBANA_PORT=5601
GRAFANA_PORT=3000
"@
    
    Set-Content -Path $Script:EnvFile -Value $envContent
    Write-Success ".env file created with secure credentials"
    
    return @{
        ElasticPassword = $elasticPassword
        KibanaPassword = $kibanaPassword
        LogstashPassword = $logstashPassword
        GrafanaPassword = $grafanaPassword
        WinlogbeatPassword = $winlogbeatPassword
    }
}

# Generate docker-compose.yml
function New-DockerComposeFile {
    Write-Info "Generating docker-compose.yml..."
    
    $composeContent = @'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELASTIC_VERSION}
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - cluster.routing.allocation.disk.threshold_enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    ports:
      - "${ELASTICSEARCH_PORT}:9200"
    volumes:
      - ./elasticsearch/data:/usr/share/elasticsearch/data:rw
    networks:
      - elk
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=5s || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 30
      start_period: 90s

  logstash:
    image: docker.elastic.co/logstash/logstash:${ELASTIC_VERSION}
    container_name: logstash
    environment:
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - LOGSTASH_PASSWORD=${LOGSTASH_PASSWORD}
      - xpack.monitoring.enabled=false
      - LOGSTASH_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "${LOGSTASH_PORT}:5044"
      - "9600:9600"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    networks:
      - elk
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9600 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 60s

  kibana:
    image: docker.elastic.co/kibana/kibana:${ELASTIC_VERSION}
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=${KIBANA_PASSWORD}
      - SERVER_HOST=0.0.0.0
      - LOGGING_ROOT_LEVEL=error
    ports:
      - "${KIBANA_PORT}:5601"
    networks:
      - elk
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:5601/api/status || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 60s

  grafana:
    image: grafana/grafana:${GRAFANA_VERSION}
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_USERNAME}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_LOG_LEVEL=error
    ports:
      - "${GRAFANA_PORT}:3000"
    volumes:
      - ./grafana/data:/var/lib/grafana
    networks:
      - elk
    depends_on:
      - elasticsearch
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 30s

networks:
  elk:
    driver: bridge
'@
    
    Set-Content -Path $Script:DockerComposeFile -Value $composeContent
    Write-Success "docker-compose.yml created"
}

# Generate Logstash configuration
function New-LogstashConfig {
    Write-Info "Generating Logstash configuration..."
    
    # We don't need logstash.yml anymore - using environment variables
    # Just create the pipeline configuration
    
    $pipelineContent = @"
input {
  beats {
    port => 5044
    ssl => false
  }
}

filter {
  if [winlog] {
    mutate {
      add_field => { "[@metadata][target_index]" => "winlogbeat-%{+YYYY.MM.dd}" }
    }
  }
  
  # Parse Windows Event Log data
  if [event][code] {
    mutate {
      add_field => { "event_id" => "%{[event][code]}" }
    }
  }
  
  # Add timestamp
  if [winlog][time_created] {
    date {
      match => [ "[winlog][time_created]", "ISO8601" ]
      target => "@timestamp"
    }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    user => "elastic"
    password => "`${ELASTIC_PASSWORD}"
    index => "%{[@metadata][target_index]}"
    manage_template => true
  }
  
  # Debug output (comment out in production)
  stdout {
    codec => rubydebug
  }
}
"@
    
    Set-Content -Path $Script:LogstashPipelineFile -Value $pipelineContent
    Write-Success "Logstash configuration created"
}

# Generate Winlogbeat configuration
function New-WinlogbeatConfig {
    param(
        [string]$LogstashHost,
        [int]$LogstashPort = 5044,
        [string]$Username = "winlogbeat_writer",
        [string]$Password
    )
    
    Write-Info "Generating Winlogbeat configuration..."
    
    $winlogbeatConfig = @"
winlogbeat.event_logs:
  - name: Application
    ignore_older: 72h
  - name: System
    ignore_older: 72h
  - name: Security
    ignore_older: 72h
  - name: Microsoft-Windows-PowerShell/Operational
    ignore_older: 72h

winlogbeat.registry_file: C:/ProgramData/winlogbeat/.winlogbeat.yml

output.logstash:
  hosts: ["${LogstashHost}:${LogstashPort}"]
  
logging.level: info
logging.to_files: true
logging.files:
  path: C:/ProgramData/winlogbeat/Logs
  name: winlogbeat
  keepfiles: 7
  permissions: 0644

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
"@
    
    # Create config in both locations
    Set-Content -Path $Script:WinlogbeatConfigFile -Value $winlogbeatConfig
    
    if (Test-Path $Script:WinlogbeatInstallDir) {
        Set-Content -Path "$Script:WinlogbeatInstallDir\winlogbeat.yml" -Value $winlogbeatConfig
    }
    
    Write-Success "Winlogbeat configuration created"
}

# Setup Elasticsearch users
function Initialize-ElasticsearchUsers {
    param([hashtable]$Credentials)
    
    Write-Info "Waiting for Elasticsearch to be fully ready..."

    # Wait for Elasticsearch to be truly ready
    $maxAttempts = 30
    $attempt = 0
    $elasticUrl = "http://localhost:9200"

    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-RestMethod -Uri "$elasticUrl/_cluster/health" -Method Get -ErrorAction Stop
            if ($response.status -eq "green" -or $response.status -eq "yellow") {
                Write-Success "Elasticsearch is ready!"
                break
            }
        } catch {
            Write-Host "." -NoNewline
        }
        Start-Sleep -Seconds 2
        $attempt++
    }
    Write-Host ""

    if ($attempt -ge $maxAttempts) {
        Write-Warning "Elasticsearch took too long to be ready, but continuing..."
    }

    Start-Sleep -Seconds 5

    $authHeader = @{
        Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$($Credentials.ElasticPassword)"))
    }

    try {
        # Update Kibana system password FIRST
        Write-Info "Setting Kibana system password..."
        $kibanaUser = @{
            password = $Credentials.KibanaPassword
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$elasticUrl/_security/user/kibana_system/_password" `
            -Method Post `
            -Headers $authHeader `
            -ContentType "application/json" `
            -Body $kibanaUser `
            -ErrorAction Stop

        Write-Success "Kibana system password set"

        # Update Logstash system password
        Write-Info "Setting Logstash system password..."
        $logstashUser = @{
            password = $Credentials.LogstashPassword
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$elasticUrl/_security/user/logstash_system/_password" `
            -Method Post `
            -Headers $authHeader `
            -ContentType "application/json" `
            -Body $logstashUser `
            -ErrorAction Stop

        Write-Success "Logstash system password set"

        # Create Winlogbeat user
        Write-Info "Creating Winlogbeat user..."
        $winlogbeatUser = @{
            password = $Credentials.WinlogbeatPassword
            roles = @("superuser")
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$elasticUrl/_security/user/winlogbeat_writer" `
            -Method Put `
            -Headers $authHeader `
            -ContentType "application/json" `
            -Body $winlogbeatUser `
            -ErrorAction Stop

        Write-Success "Winlogbeat user created"

        # Now restart Kibana and Logstash to use new passwords
        Write-Info "Restarting Kibana and Logstash with new credentials..."
        Push-Location $Script:BaseDir
        docker-compose restart kibana logstash 2>&1 | Out-Null
        Pop-Location
        Write-Success "Services restarted"

    } catch {
        Write-Error "Failed to configure users: $_"
        Write-Warning "You may need to configure users manually"
        Write-Info "Error details: $($_.Exception.Message)"
    }
}

# Install Winlogbeat
function Install-Winlogbeat {
    Write-Info "Installing Winlogbeat $Script:WinlogbeatVersion..."
    
    $downloadUrl = "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-$Script:WinlogbeatVersion-windows-x86_64.zip"
    $zipFile = "$env:TEMP\winlogbeat.zip"
    
    try {
        # Download Winlogbeat
        Write-Info "Downloading Winlogbeat..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        Write-Success "Winlogbeat downloaded"
        
        # Extract
        Write-Info "Extracting Winlogbeat..."
        Expand-Archive -Path $zipFile -DestinationPath $env:TEMP -Force
        
        # Move to installation directory
        $extractedPath = "$env:TEMP\winlogbeat-$Script:WinlogbeatVersion-windows-x86_64"
        if (Test-Path $Script:WinlogbeatInstallDir) {
            Remove-Item -Path $Script:WinlogbeatInstallDir -Recurse -Force
        }
        Move-Item -Path $extractedPath -Destination $Script:WinlogbeatInstallDir -Force
        Write-Success "Winlogbeat extracted"
        
        # Copy configuration
        Copy-Item -Path $Script:WinlogbeatConfigFile -Destination "$Script:WinlogbeatInstallDir\winlogbeat.yml" -Force
        
        # Install service
        Write-Info "Installing Winlogbeat service..."
        Push-Location $Script:WinlogbeatInstallDir
        & .\install-service-winlogbeat.ps1
        Pop-Location
        Write-Success "Winlogbeat service installed"
        
        # Start service
        Write-Info "Starting Winlogbeat service..."
        Start-Service -Name "winlogbeat"
        Write-Success "Winlogbeat service started"
        
        # Cleanup
        Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Error "Failed to install Winlogbeat: $_"
        throw
    }
}

# Check Docker container health
function Test-ContainerHealth {
    param([string]$ContainerName)
    
    try {
        $health = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
        return $health -eq "healthy"
    } catch {
        return $false
    }
}

# Start Docker stack
function Start-DockerStack {
    Write-Info "Starting Docker stack..."
    Write-Info "This may take a few minutes on first run (downloading images)..."
    
    Push-Location $Script:BaseDir
    try {
        # Start containers with full output
        Write-Host ""
        docker-compose up -d 2>&1 | ForEach-Object {
            Write-Host $_
        }
        Write-Host ""
        
        # Check if containers actually started
        $runningContainers = docker-compose ps --format json 2>$null | ConvertFrom-Json
        if ($null -eq $runningContainers -or $runningContainers.Count -eq 0) {
            Write-Error "No containers are running. Check Docker Desktop is running properly."
            docker-compose logs --tail=50
            throw "Failed to start containers"
        }
        
        Write-Success "Docker containers started"
        
        Write-Info "Waiting for services to be healthy (this may take 3-5 minutes)..."
        Write-Info "You can monitor logs with: docker-compose logs -f"
        Write-Host ""
        
        $maxWait = 300
        $waited = 0
        $interval = 10
        
        $containers = @("elasticsearch", "logstash", "kibana", "grafana")
        
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds $interval
            $waited += $interval
            
            $healthyCount = 0
            $statusMessages = @()
            
            foreach ($container in $containers) {
                if (Test-ContainerHealth $container) {
                    $healthyCount++
                    $statusMessages += "[OK] $container"
                } else {
                    $status = docker inspect --format='{{.State.Status}}' $container 2>$null
                    $statusMessages += "[..] $container ($status)"
                }
            }
            
            Write-Info "Progress ($waited/$maxWait seconds):"
            foreach ($msg in $statusMessages) {
                Write-Host "  $msg"
            }
            Write-Host ""
            
            if ($healthyCount -eq $containers.Count) {
                Write-Success "All services are healthy!"
                break
            }
            
            # If Elasticsearch is still unhealthy after 2 minutes, show logs
            if ($waited -ge 120 -and -not (Test-ContainerHealth "elasticsearch")) {
                Write-Warning "Elasticsearch is taking longer than expected. Checking logs..."
                Write-Host ""
                docker logs elasticsearch --tail 20
                Write-Host ""
            }
        }
        
        if ($waited -ge $maxWait) {
            Write-Warning "Timeout reached. Some services may not be fully healthy yet."
            Write-Info "Check container status with: docker-compose ps"
            Write-Info "Check logs with: docker-compose logs [service-name]"
            Write-Host ""
            
            # Show current status
            docker-compose ps
        }
        
    } catch {
        Write-Error "Failed to start Docker stack: $_"
        throw
    } finally {
        Pop-Location
    }
}

# Display final information
function Show-CompletionInfo {
    param([hashtable]$Credentials)
    
    Write-Host "`n" -NoNewline
    Write-Success "========================================="
    Write-Success "    ELK Stack Setup Complete!"
    Write-Success "========================================="
    Write-Host "`n"
    
    Write-Info "Access URLs:"
    Write-Host "  Elasticsearch: http://localhost:9200" -ForegroundColor White
    Write-Host "  Kibana:        http://localhost:5601" -ForegroundColor White
    Write-Host "  Grafana:       http://localhost:3000" -ForegroundColor White
    Write-Host "  Logstash:      localhost:5044 (Beats input)" -ForegroundColor White
    Write-Host "`n"
    
    Write-Info "Credentials:"
    Write-Host "  Elasticsearch:" -ForegroundColor White
    Write-Host "    Username: elastic" -ForegroundColor White
    Write-Host "    Password: $($Credentials.ElasticPassword)" -ForegroundColor Yellow
    Write-Host "`n"
    Write-Host "  Kibana:" -ForegroundColor White
    Write-Host "    Username: elastic" -ForegroundColor White
    Write-Host "    Password: $($Credentials.ElasticPassword)" -ForegroundColor Yellow
    Write-Host "`n"
    Write-Host "  Grafana:" -ForegroundColor White
    Write-Host "    Username: admin" -ForegroundColor White
    Write-Host "    Password: $($Credentials.GrafanaPassword)" -ForegroundColor Yellow
    Write-Host "`n"
    Write-Host "  Winlogbeat:" -ForegroundColor White
    Write-Host "    Username: winlogbeat_writer" -ForegroundColor White
    Write-Host "    Password: $($Credentials.WinlogbeatPassword)" -ForegroundColor Yellow
    Write-Host "`n"
    
    Write-Info "Useful Commands:"
    Write-Host "  Check status:  docker-compose ps" -ForegroundColor White
    Write-Host "  View logs:     docker-compose logs -f [service-name]" -ForegroundColor White
    Write-Host "  Stop services: docker-compose down" -ForegroundColor White
    Write-Host "  Restart:       docker-compose restart [service-name]" -ForegroundColor White
    Write-Host "`n"
    
    Write-Info "Log File: $Script:LogFile"
    Write-Info "Installation Directory: $Script:BaseDir"
    Write-Host "`n"
    
    Write-Success "========================================="
    Write-Host "`n"
}

# Show Winlogbeat-only completion info
function Show-WinlogbeatCompletionInfo {
    param([string]$LogstashHost, [int]$LogstashPort)
    
    Write-Host "`n" -NoNewline
    Write-Success "========================================="
    Write-Success "   Winlogbeat Agent Setup Complete!"
    Write-Success "========================================="
    Write-Host "`n"
    
    Write-Info "Configuration:"
    Write-Host "  Logstash Host: $LogstashHost" -ForegroundColor White
    Write-Host "  Logstash Port: $LogstashPort" -ForegroundColor White
    Write-Host "  Installation:  $Script:WinlogbeatInstallDir" -ForegroundColor White
    Write-Host "`n"
    
    Write-Info "Service Status:"
    $service = Get-Service -Name "winlogbeat" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "  Winlogbeat Service: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' })
    }
    Write-Host "`n"
    
    Write-Info "Useful Commands:"
    Write-Host "  Check service:  Get-Service winlogbeat" -ForegroundColor White
    Write-Host "  View logs:      Get-Content 'C:\ProgramData\winlogbeat\Logs\winlogbeat' -Tail 50 -Wait" -ForegroundColor White
    Write-Host "  Restart:        Restart-Service winlogbeat" -ForegroundColor White
    Write-Host "`n"
    
    Write-Success "========================================="
    Write-Host "`n"
}

# Mode 1: Full ELK Stack Installation
function Install-FullStack {
    Write-Info "Starting Full ELK Stack + Winlogbeat installation..."
    
    # Check Docker
    if (-not (Test-DockerRunning)) {
        Write-Error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    }
    
    # Check available memory
    $totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($totalMemory -lt 8) {
        Write-Warning "Your system has less than 8GB RAM ($([math]::Round($totalMemory, 2))GB detected)."
        Write-Warning "ELK Stack may run slowly. Consider reducing Java heap size in docker-compose.yml"
        $continue = Read-Host "Continue anyway? (Y/N)"
        if ($continue -ne "Y") {
            exit 0
        }
    }
    
    # Clean install if requested
    if ($CleanInstall) {
        Remove-ExistingSetup
    }
    
    # Create directory structure
    New-DirectoryStructure
    
    # Generate configurations
    $credentials = New-EnvironmentFile
    New-DockerComposeFile
    New-LogstashConfig
    New-WinlogbeatConfig -LogstashHost "localhost" -LogstashPort 5044 -Password $credentials.WinlogbeatPassword
    
    # Start ONLY Elasticsearch first
    Write-Info "Starting Elasticsearch first..."
    Push-Location $Script:BaseDir
    docker-compose up -d elasticsearch
    Pop-Location
    
    # Wait for Elasticsearch and configure users
    Write-Info "Configuring Elasticsearch users..."
    Initialize-ElasticsearchUsers -Credentials $credentials
    
    # Now start remaining services
    Write-Info "Starting remaining services (Kibana, Logstash, Grafana)..."
    Start-DockerStack
    
    # Install Winlogbeat
    Install-Winlogbeat
    
    # Show completion info
    Show-CompletionInfo -Credentials $credentials
}

# Mode 2: Winlogbeat-Only Installation
function Install-WinlogbeatOnly {
    Write-Info "Starting Winlogbeat-only (Remote Agent) installation..."
    
    # Prompt for ELK host details
    Write-Host "`n"
    $elkHost = Read-Host "Enter ELK Host IP or Domain (e.g., 192.168.1.100 or elk.example.com)"
    $elkPort = Read-Host "Enter Logstash Port (default: 5044)"
    if ([string]::IsNullOrWhiteSpace($elkPort)) {
        $elkPort = 5044
    }
    
    # Create minimal directory structure
    if (-not (Test-Path $Script:BaseDir)) {
        New-Item -Path $Script:BaseDir -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path "$Script:BaseDir\winlogbeat")) {
        New-Item -Path "$Script:BaseDir\winlogbeat" -ItemType Directory -Force | Out-Null
    }
    
    # Generate Winlogbeat config for remote host
    New-WinlogbeatConfig -LogstashHost $elkHost -LogstashPort $elkPort -Password ""
    
    # Install Winlogbeat
    Install-Winlogbeat
    
    # Show completion info
    Show-WinlogbeatCompletionInfo -LogstashHost $elkHost -LogstashPort $elkPort
}

# Main execution
function Main {
    # Initialize log file
    "========================================" | Out-File -FilePath $Script:LogFile
    "ELK Stack Setup - $(Get-Date)" | Out-File -FilePath $Script:LogFile -Append
    "========================================" | Out-File -FilePath $Script:LogFile -Append
    
    Write-Host "`n"
    Write-Success "========================================="
    Write-Success "  ELK Stack One-Click Setup Automation"
    Write-Success "========================================="
    Write-Host "`n"
    
    # Prompt for installation mode
    Write-Info "Choose installation mode:"
    Write-Host "  [1] Full ELK Stack + Winlogbeat (Host Setup)" -ForegroundColor White
    Write-Host "  [2] Winlogbeat-only (Remote Agent)" -ForegroundColor White
    Write-Host "`n"
    
    $mode = Read-Host "Enter choice (1 or 2)"
    
    switch ($mode) {
        "1" {
            Install-FullStack
        }
        "2" {
            Install-WinlogbeatOnly
        }
        default {
            Write-Error "Invalid choice. Please run the script again and select 1 or 2."
            exit 1
        }
    }
    
    Write-Success "Setup completed successfully!"
}

# Run main function
try {
    Main
} catch {
    Write-Error "Setup failed: $_"
    Write-Error "Check $Script:LogFile for details"
    exit 1
}
