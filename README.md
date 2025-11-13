# Windows ELK + Grafana Monitoring Stack

A fully automated, production-ready ELK + Grafana monitoring stack with Winlogbeat for comprehensive Windows Event Log monitoring. This project provides **true one-click deployment** using PowerShell and Docker, with dual installation modes for both full stack deployment and remote agent installation.

## 🚀 Key Features

- **🎯 True One-Click Setup**: Single PowerShell command deploys the entire stack
- **🔐 Auto-Generated Credentials**: Secure random passwords for all services
- **🏢 Dual Installation Modes**: 
  - Full ELK Stack + Winlogbeat (Host Setup)
  - Winlogbeat-only (Remote Agent Mode)
- **📦 Self-Contained**: All configurations auto-generated - no manual editing required
- **🔄 Automated User Management**: Elasticsearch users created and configured automatically
- **🛡️ Production-Ready**: Latest Elastic Stack 8.15.0 with security enabled
- **📊 Pre-Integrated Grafana**: Advanced dashboards with Elasticsearch datasource
- **🪟 Windows Event Collection**: Application, System, Security, and PowerShell logs
- **🐳 Fully Containerized**: Complete isolation via Docker with health checks
- **⚡ Optimized Performance**: Proper memory allocation and restart policies

## 📋 Prerequisites

Before running the stack, ensure you have:

- **Windows 10/11** or **Windows Server 2019+**
- **PowerShell 5.1+** (Run as Administrator)
- **Docker Desktop for Windows** with WSL2 backend enabled
- **Minimum 8GB RAM** (16GB recommended for production)
- **10GB free disk space** minimum
- **Internet connection** for Docker image downloads (first run only)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Windows Host System                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐│
│  │   Winlogbeat    │───▶│    Logstash      │───▶│Elasticsearch││
│  │  (Windows Service)   │  (Port 5044)     │    │ (Port 9200) ││
│  │  Event Collector│    │  Beat Processor  │    │ Data Store  ││
│  └─────────────────┘    └──────────────────┘    └─────────────┘│
│                                                         │         │
│  ┌─────────────────┐    ┌──────────────────┐         │         │
│  │     Grafana     │    │      Kibana      │◀────────┘         │
│  │  (Port 3000)    │    │   (Port 5601)    │                   │
│  │  Visualization  │    │   Analytics UI   │                   │
│  └─────────────────┘    └──────────────────┘                   │
│                                                                   │
│  All services run in isolated Docker containers with auto-      │
│  restart policies and health monitoring                          │
└─────────────────────────────────────────────────────────────────┘

Remote Agent Mode (Optional):
┌──────────────────┐          ┌─────────────────────────────────┐
│ Remote Windows   │          │     Central ELK Host           │
│    Machine       │          │                                 │
│  ┌────────────┐  │          │  ┌──────────────────┐          │
│  │ Winlogbeat │──┼─────────▶│  │    Logstash      │          │
│  │  (Agent)   │  │  Port    │  │   (Port 5044)    │          │
│  └────────────┘  │  5044    │  └──────────────────┘          │
└──────────────────┘          └─────────────────────────────────┘
```

## 🚀 Quick Start

### Mode 1: Full Stack Installation (Host Setup)

Perfect for setting up a central monitoring server.

```powershell
# 1. Clone the repository
git clone https://github.com/SecByShresth/Windows-ELK-Monitoring-Stack.git
cd Windows-ELK-Monitoring-Stack

# 2. Run one-click setup as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\oneclick-setup.ps1 -CleanInstall

# 3. Select Mode [1] when prompted
# Enter choice (1 or 2): 1
```

**What happens automatically:**
1. ✅ Cleans any existing installation
2. ✅ Creates directory structure
3. ✅ Generates secure `.env` file with random passwords
4. ✅ Creates `docker-compose.yml` with optimized settings
5. ✅ Configures Logstash pipeline for Winlogbeat
6. ✅ Starts Elasticsearch and waits for readiness
7. ✅ Sets up Elasticsearch users (kibana_system, logstash_system, winlogbeat_writer)
8. ✅ Starts Kibana, Logstash, and Grafana
9. ✅ Downloads and installs Winlogbeat 8.15.1
10. ✅ Registers Winlogbeat as Windows service
11. ✅ Displays all credentials and access URLs

### Mode 2: Remote Agent Installation (Winlogbeat Only)

Perfect for adding Windows machines to an existing ELK stack.

```powershell
# 1. On the remote Windows machine
.\oneclick-setup.ps1 -CleanInstall

# 2. Select Mode [2] when prompted
# Enter choice (1 or 2): 2

# 3. Provide ELK host details
# Enter ELK Host IP or Domain: 192.168.1.100
# Enter Logstash Port (default: 5044): 5044
```

**What happens:**
1. ✅ Installs Winlogbeat only (no Docker required)
2. ✅ Configures connection to remote ELK host
3. ✅ Registers and starts Winlogbeat service
4. ✅ Begins forwarding logs to central server

## 🎯 Post-Installation

After successful setup, you'll see:

```
=========================================
    ELK Stack Setup Complete!
=========================================

Access URLs:
  Elasticsearch: http://localhost:9200
  Kibana:        http://localhost:5601
  Grafana:       http://localhost:3000
  Logstash:      localhost:5044 (Beats input)

Credentials:
  Elasticsearch:
    Username: elastic
    Password: [16-char random password]

  Kibana:
    Username: elastic
    Password: [same as Elasticsearch]

  Grafana:
    Username: admin
    Password: [16-char random password]

  Winlogbeat:
    Username: winlogbeat_writer
    Password: [16-char random password]
```

**💾 Save these credentials!** They are also stored in `elk-stack\.env`

## 📁 Project Structure

```
Windows-ELK-Monitoring-Stack/
├── oneclick-setup.ps1              # ⭐ Main automation script (dual mode)
├── README.md                       # This file
├── LICENSE                         # MIT License
│
└── elk-stack/                      # Auto-generated during setup
    ├── .env                        # Generated credentials
    ├── docker-compose.yml          # Generated Docker config
    │
    ├── elasticsearch/
    │   └── data/                   # Persistent data volume
    │
    ├── logstash/
    │   └── pipeline/
    │       └── winlogbeat.conf     # Auto-generated pipeline
    │
    ├── kibana/
    │   └── config/                 # Kibana settings
    │
    ├── grafana/
    │   └── data/                   # Grafana data & dashboards
    │
    └── winlogbeat/
        └── winlogbeat.yml          # Auto-generated config

C:\Program Files\Winlogbeat/        # Installed by script
    ├── winlogbeat.exe
    ├── winlogbeat.yml
    └── logs/
```

## ⚙️ Configuration Details

### Auto-Generated Environment Variables

The script creates `.env` with alphanumeric passwords (no special chars to avoid escaping issues):

```env
# Elasticsearch Configuration
ELASTIC_VERSION=8.15.0
ELASTIC_PASSWORD=abc123XYZ789def4
ELASTIC_USERNAME=elastic

# Kibana Configuration  
KIBANA_PASSWORD=xyz789ABC123ghi5
KIBANA_USERNAME=kibana_system

# Logstash Configuration
LOGSTASH_PASSWORD=def456GHI789jkl0
LOGSTASH_USERNAME=logstash_system

# Grafana Configuration
GRAFANA_VERSION=11.3.0
GRAFANA_PASSWORD=mno789PQR123stu6
GRAFANA_USERNAME=admin

# Winlogbeat Configuration
WINLOGBEAT_VERSION=8.15.1
WINLOGBEAT_PASSWORD=vwx012YZA345bcd7
WINLOGBEAT_USERNAME=winlogbeat_writer

# Network Configuration
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=9200
LOGSTASH_PORT=5044
KIBANA_PORT=5601
GRAFANA_PORT=3000
```

### Stack Components

#### Elasticsearch 8.15.0 (Port 9200)
- **Security**: Enabled with user authentication
- **Memory**: 2GB heap (configurable)
- **Storage**: Docker volume with full permissions
- **Health Check**: Automatic readiness verification
- **Users**: Auto-configured (elastic, kibana_system, logstash_system, winlogbeat_writer)

#### Kibana 8.15.0 (Port 5601)
- **Authentication**: Uses kibana_system user
- **Auto-restart**: Restarts after password configuration
- **Index Pattern**: Works with winlogbeat-* indices

#### Logstash 8.15.0 (Port 5044)
- **Input**: Beats protocol (Winlogbeat)
- **Memory**: 512MB heap
- **Pipeline**: Auto-configured for Windows Event Logs
- **Output**: Daily indices (winlogbeat-YYYY.MM.dd)
- **No config file mount**: Environment variables only (prevents read-only errors)

#### Grafana 11.3.0 (Port 3000)
- **Datasource**: Elasticsearch (manual setup required)
- **Persistent Storage**: Docker volume
- **Authentication**: Admin user with random password

#### Winlogbeat 8.15.1 (Windows Service)
- **Logs Collected**:
  - Application (errors, warnings, info)
  - System (hardware, services, drivers)
  - Security (authentication, authorization)
  - PowerShell/Operational (script execution)
- **Retention**: Ignores events older than 72 hours
- **Output**: Logstash (Port 5044)
- **Registry**: C:/ProgramData/winlogbeat/.winlogbeat.yml

### Logstash Pipeline

Auto-generated pipeline processes Windows Event Logs:

```ruby
input {
  beats {
    port => 5044
    ssl => false
  }
}

filter {
  # Creates daily indices
  if [winlog] {
    mutate {
      add_field => { "[@metadata][target_index]" => "winlogbeat-%{+YYYY.MM.dd}" }
    }
  }
  
  # Extracts event ID
  if [event][code] {
    mutate {
      add_field => { "event_id" => "%{[event][code]}" }
    }
  }
  
  # Parses timestamps
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
    password => "${ELASTIC_PASSWORD}"
    index => "%{[@metadata][target_index]}"
  }
}
```

## 🛠️ Management Commands

### Check Stack Status
```powershell
cd elk-stack
docker-compose ps

# Should show all services as "Up" and "healthy"
```

### View Service Logs
```powershell
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f elasticsearch
docker-compose logs -f kibana
docker-compose logs -f logstash
docker-compose logs -f grafana
```

### Check Winlogbeat Status
```powershell
# Service status
Get-Service winlogbeat

# View logs
Get-Content "C:\ProgramData\winlogbeat\Logs\winlogbeat" -Tail 50 -Wait

# Restart service
Restart-Service winlogbeat
```

### Stop/Start Stack
```powershell
cd elk-stack

# Stop all services
docker-compose down

# Start all services
docker-compose up -d

# Restart specific service
docker-compose restart kibana
```

### Complete Cleanup
```powershell
# Run script with clean install
.\oneclick-setup.ps1 -CleanInstall

# This removes:
# - All Docker containers and volumes
# - elk-stack directory
# - Winlogbeat service and installation
```

## 🔍 Troubleshooting

### Common Issues & Solutions

#### 1. Docker Not Running
```
Error: Cannot connect to Docker daemon
```
**Solution**: Start Docker Desktop and ensure WSL2 backend is enabled

#### 2. Insufficient Memory
```
Elasticsearch container keeps restarting
```
**Solution**: 
- Open Docker Desktop → Settings → Resources
- Increase Memory to 8GB minimum
- Apply & Restart

#### 3. Port Conflicts
```
Error: Bind for 0.0.0.0:9200 failed: port is already allocated
```
**Solution**:
```powershell
# Check what's using the port
Get-NetTCPConnection -LocalPort 9200

# Stop the conflicting service or change ports in elk-stack/.env
```

#### 4. Elasticsearch Not Starting
```powershell
# Check logs
cd elk-stack
docker-compose logs elasticsearch

# Common fix: Remove data and restart
docker-compose down -v
docker-compose up -d
```

#### 5. Authentication Errors in Kibana/Logstash
```
"failed to authenticate user [kibana_system]"
```
**Solution**: The script handles this automatically. If you see this:
```powershell
# Manually set passwords
cd elk-stack
docker-compose restart elasticsearch
Start-Sleep 30

# Wait for ES to be ready, then restart dependent services
docker-compose restart kibana logstash
```

#### 6. Winlogbeat Not Sending Logs
```powershell
# Check service
Get-Service winlogbeat

# If stopped, start it
Start-Service winlogbeat

# Check connectivity to Logstash
Test-NetConnection localhost -Port 5044

# View Winlogbeat logs for errors
Get-Content "C:\ProgramData\winlogbeat\Logs\winlogbeat" -Tail 100
```

### Health Check Commands

```powershell
# Elasticsearch cluster health
Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" `
    -Method Get `
    -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:YOUR_PASSWORD"))}

# Check for Winlogbeat indices
Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices/winlogbeat*?v" `
    -Method Get `
    -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:YOUR_PASSWORD"))}

# Kibana status
Invoke-RestMethod -Uri "http://localhost:5601/api/status"

# Grafana health
Invoke-RestMethod -Uri "http://localhost:3000/api/health"
```

## 📊 Using the Stack

### Kibana - Log Analysis

1. **Access**: http://localhost:5601
2. **Login**: Use `elastic` username and password from setup output
3. **Create Index Pattern**:
   - Go to Stack Management → Index Patterns
   - Create pattern: `winlogbeat-*`
   - Time field: `@timestamp`
4. **Discover**: View real-time logs with filters
5. **Dashboard**: Create visualizations

**Useful KQL Queries**:
```
# Failed login attempts
event.code: 4625

# Application errors
log.level: "error" and winlog.channel: "Application"

# PowerShell execution
winlog.channel: "Microsoft-Windows-PowerShell/Operational"

# Events from last hour
@timestamp >= now-1h
```

### Grafana - Dashboards

1. **Access**: http://localhost:3000
2. **Login**: `admin` / (password from setup output)
3. **Add Elasticsearch Datasource**:
   - Configuration → Data Sources → Add data source
   - Select Elasticsearch
   - URL: `http://elasticsearch:9200`
   - Auth: Basic Auth
   - User: `elastic`
   - Password: (from setup output)
   - Index: `winlogbeat-*`
   - Time field: `@timestamp`
4. **Create Dashboards**: Build custom visualizations

## 🔐 Security Considerations

### Current Configuration (Development)
- ✅ Elasticsearch security **enabled**
- ✅ User authentication required
- ✅ Randomly generated passwords
- ⚠️ HTTP only (no SSL/TLS)
- ⚠️ Suitable for **local development/testing**

### Production Hardening Checklist

- [ ] Enable SSL/TLS on all services
- [ ] Use strong 32+ character passwords
- [ ] Implement role-based access control (RBAC)
- [ ] Enable audit logging
- [ ] Configure firewall rules (allow only necessary ports)
- [ ] Use separate networks for each tier
- [ ] Implement log retention policies
- [ ] Regular security updates
- [ ] Monitor for failed authentication attempts
- [ ] Backup Elasticsearch data regularly

## 🎨 Customization

### Add More Event Log Sources

Edit `elk-stack/winlogbeat/winlogbeat.yml`:

```yaml
winlogbeat.event_logs:
  - name: Application
  - name: System
  - name: Security
  - name: Microsoft-Windows-PowerShell/Operational
  - name: Microsoft-Windows-Sysmon/Operational    # Sysmon logs
  - name: Microsoft-Windows-DNS-Client/Operational
```

Then restart:
```powershell
Restart-Service winlogbeat
```

### Adjust Memory Allocation

Edit `elk-stack/docker-compose.yml`:

```yaml
# For Elasticsearch (default: 2g)
- "ES_JAVA_OPTS=-Xms4g -Xmx4g"

# For Logstash (default: 512m)
- LOGSTASH_JAVA_OPTS=-Xms1g -Xmx1g
```

Apply changes:
```powershell
docker-compose down
docker-compose up -d
```

### Change Ports

Edit `elk-stack/.env`:

```env
ELASTICSEARCH_PORT=9200
KIBANA_PORT=5601
GRAFANA_PORT=3000
LOGSTASH_PORT=5044
```

Recreate containers:
```powershell
docker-compose down
docker-compose up -d
```

## 🔄 Updates & Maintenance

### Update Elastic Stack
```powershell
# Edit elk-stack/.env
ELASTIC_VERSION=8.16.0  # New version

# Pull new images and recreate
docker-compose pull
docker-compose down
docker-compose up -d
```

### Update Winlogbeat
```powershell
# Stop service
Stop-Service winlogbeat

# Edit oneclick-setup.ps1
$Script:WinlogbeatVersion = "8.16.0"

# Re-run installation (Mode 1 or 2)
.\oneclick-setup.ps1
```

### Backup & Restore

**Backup**:
```powershell
# Backup Elasticsearch data
docker-compose exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-snapshot

# Or backup the entire data directory
Copy-Item -Path "elk-stack\elasticsearch\data" -Destination "backup\es-data" -Recurse
```

**Restore**:
```powershell
# Stop services
docker-compose down

# Restore data
Copy-Item -Path "backup\es-data\*" -Destination "elk-stack\elasticsearch\data" -Recurse

# Start services
docker-compose up -d
```

## 📚 Documentation Links

- [Elasticsearch 8.15 Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/8.15/index.html)
- [Kibana 8.15 Documentation](https://www.elastic.co/guide/en/kibana/8.15/index.html)
- [Logstash 8.15 Documentation](https://www.elastic.co/guide/en/logstash/8.15/index.html)
- [Winlogbeat 8.15 Documentation](https://www.elastic.co/guide/en/beats/winlogbeat/8.15/index.html)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Elastic** for the comprehensive ELK Stack
- **Grafana Labs** for powerful visualization tools
- **Docker** for containerization technology
- **Microsoft** for Windows Event Logging infrastructure
- **Community contributors** for feedback and improvements

## 📞 Support & Contact

### Get Help
- 📖 Check the [Troubleshooting](#-troubleshooting) section
- 🔍 Search [existing issues](https://github.com/SecByShresth/Windows-ELK-Monitoring-Stack/issues)
- 💬 Ask questions in [Discussions](https://github.com/SecByShresth/Windows-ELK-Monitoring-Stack/discussions)

### Report Issues
Create a [new issue](https://github.com/SecByShresth/Windows-ELK-Monitoring-Stack/issues/new) with:
- Windows version
- Docker Desktop version
- PowerShell version
- Error messages
- Relevant logs (`docker-compose logs`)

## 📊 Version Information

| Component | Version | Notes |
|-----------|---------|-------|
| Elasticsearch | 8.15.0 | Stable release |
| Kibana | 8.15.0 | Matched with ES |
| Logstash | 8.15.0 | Matched with ES |
| Winlogbeat | 8.15.1 | Latest stable |
| Grafana | 11.3.0 | Latest stable |

**Tested on:**
- Windows 10 21H2+
- Windows 11 22H2+
- Windows Server 2019
- Windows Server 2022

---

## ⭐ Star History

If this project helped you, please consider giving it a ⭐!

---

**Built with ❤️ for Windows System Administrators, DevOps Engineers, and Security Professionals**

*Comprehensive Windows Event Log monitoring made simple and automated*
