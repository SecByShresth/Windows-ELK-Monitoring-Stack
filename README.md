# Windows ELK + Grafana Monitoring Stack

A fully automated, Windows-native ELK + Grafana monitoring stack with Winlogbeat for comprehensive Windows Event Log monitoring. This project provides one-click deployment using PowerShell and Docker, with HTTP configuration for easy local development and testing.

## 🚀 Features

- **Self-hosted ELK Stack**: Elasticsearch, Logstash, and Kibana running on Windows via Docker
- **Grafana Integration**: Advanced dashboards for log visualization and monitoring
- **Winlogbeat Collection**: Automated collection of Application, System, and Security Windows Event Logs
- **HTTP Configuration**: Simplified setup without SSL certificates for local development
- **One-Click Deployment**: Automated setup via `oneclick-setup.ps1` PowerShell script
- **Pre-configured Components**: Ready-to-use Kibana index patterns and Grafana provisioning
- **Docker Containerized**: Complete stack runs in isolated Docker containers
- **Latest Images**: Uses Elastic Stack 8.11.2 and latest Grafana

## 📋 Prerequisites

Before running the stack, ensure you have:

- **Windows 10/11** or **Windows Server 2016+**
- **PowerShell 5.1+** (PowerShell Core 7+ recommended)
- **Docker Desktop for Windows** with WSL2 backend
- **Administrator privileges** for PowerShell execution and Winlogbeat installation
- **Minimum 4GB RAM** (8GB recommended)
- **5GB free disk space** minimum

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Winlogbeat    │───▶│    Logstash      │───▶│ Elasticsearch   │
│ (Event Collector)│    │ (Port 5044)      │    │ (Port 9200)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    Grafana      │    │     Kibana       │    │   HTTP Only     │
│ (Port 3000)     │    │ (Port 5601)      │    │ (No SSL/TLS)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### 1. Clone the Repository

```powershell
git clone [https://github.com/yourusername/windows-elk-grafana-stack.git](https://github.com/SecByShresth/Windows-ELK-Monitoring-Stack.git)
cd windows-elk-grafana-stack
```

### 2. One-Click Setup

Open PowerShell as Administrator and run:

```powershell
# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the one-click setup
.\oneclick-setup.ps1
```

The script will automatically:
- Generate `.env` file with randomized Grafana password (from `.env.example`)
- Check Docker availability
- Start the complete ELK + Grafana stack via Docker Compose
- Wait for Elasticsearch and Kibana to become ready
- Provide access URLs and next steps

### 3. Install Winlogbeat (Recommended)

After the stack is running, install Winlogbeat to start collecting Windows Event Logs:

```powershell
# Run as Administrator
.\winlogbeat\install-winlogbeat.ps1
```

This will:
- Download Winlogbeat 8.15.1
- Install to `C:\Program Files\winlogbeat`
- Configure it to send logs to Logstash
- Register and start the Winlogbeat Windows service

### 4. Access the Services

After successful deployment, access the following services:

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| **Kibana** | http://localhost:5601 | No authentication |
| **Grafana** | http://localhost:3000 | admin / (check `.env` file) |
| **Elasticsearch** | http://localhost:9200 | No authentication |

## 📁 Project Structure

```
windows-elk-grafana-stack/
├── docker-compose.yml              # Main Docker Compose configuration
├── oneclick-setup.ps1             # One-click deployment script
├── .env                           # Environment variables (auto-generated)
├── .env.example                   # Environment template
├── README.md                      # This file
├── elasticsearch/
│   └── config/                    # Elasticsearch configuration (if needed)
├── kibana/
│   └── saved_objects/
│       └── winlogbeat-index-pattern.ndjson  # Pre-configured index pattern
├── logstash/
│   └── pipeline/
│       └── winlog.conf           # Winlogbeat processing pipeline
├── grafana/
│   ├── dashboards/
│   │   └── windows-overview.json # Sample Windows dashboard
│   └── provisioning/
│       ├── dashboards/
│       │   └── provisioning.yml  # Dashboard provisioning config
│       └── datasources/
│           └── datasource.yml    # Elasticsearch datasource config
├── winlogbeat/
│   ├── install-winlogbeat.ps1    # Winlogbeat installation script
│   └── winlogbeat.template.yml   # Winlogbeat configuration template
└── scripts/
    └── start-all.ps1             # Alternative startup script
```

## ⚙️ Configuration

### Environment Variables (.env)

The `.env` file is automatically generated from `.env.example`:

```env
ELASTIC_PASSWORD=changeme
GRAFANA_PASSWORD=[randomly_generated]
```

### Stack Components

#### Elasticsearch (Port 9200)
- **Version**: 8.11.2
- **Security**: Disabled for local development
- **Memory**: 512MB heap size
- **Data**: Stored in Docker volume `es_data`

#### Kibana (Port 5601)
- **Version**: 8.11.2
- **Authentication**: Disabled
- **Index Pattern**: `winlogbeat-*` (auto-configured)

#### Logstash (Port 5044)
- **Version**: 8.11.2
- **Input**: Beats protocol from Winlogbeat
- **Output**: Elasticsearch with daily indices (`winlogbeat-YYYY.MM.dd`)

#### Grafana (Port 3000)
- **Version**: Latest
- **Datasource**: Pre-configured Elasticsearch connection
- **Dashboards**: Auto-provisioned from `grafana/dashboards/`

### Winlogbeat Configuration

The Winlogbeat template (`winlogbeat.template.yml`) collects:

- **Application Logs**: Application events and errors (72h retention)
- **System Logs**: System-level events and hardware issues (72h retention)
- **Security Logs**: Authentication and authorization events (72h retention)

```yaml
winlogbeat.event_logs:
  - name: Application
    ignore_older: 72h
  - name: Security
    ignore_older: 72h
  - name: System
    ignore_older: 72h
```

## 🛠️ Management Commands

### Start the Stack
```powershell
# Using oneclick setup
.\oneclick-setup.ps1

# Or using Docker Compose directly
docker compose up -d

# Or using the start script
.\scripts\start-all.ps1
```

### Stop the Stack
```powershell
docker compose down
```

### View Logs
```powershell
# All services
docker compose logs -f

# Specific service
docker compose logs -f elasticsearch
docker compose logs -f kibana
docker compose logs -f logstash
docker compose logs -f grafana
```

### Update Stack
```powershell
docker compose pull
docker compose up -d
```

### Reset Data
```powershell
docker compose down -v
Remove-Item .env -ErrorAction SilentlyContinue
.\oneclick-setup.ps1
```

### Winlogbeat Management
```powershell
# Check service status
Get-Service winlogbeat

# Start/Stop service
Start-Service winlogbeat
Stop-Service winlogbeat

# View Winlogbeat logs
Get-Content "C:\Program Files\winlogbeat\logs\winlogbeat"
```

## 🔍 Troubleshooting

### Common Issues

**1. Docker Desktop not running**
```
Error: Cannot connect to the Docker daemon
Solution: Ensure Docker Desktop is running with WSL2 backend enabled
```

**2. Port conflicts**
```
Error: Port already in use
Solution: Check for services using ports 3000, 5601, 9200, 5044
netstat -ano | findstr ":9200"
```

**3. Elasticsearch not starting**
```powershell
# Check logs
docker compose logs elasticsearch

# Common issue: Insufficient memory
# Solution: Increase Docker Desktop memory limits to 4GB+
```

**4. Winlogbeat installation fails**
```
Error: Cannot download Winlogbeat
Solution: Check internet connectivity and Windows Defender/Antivirus settings
```

**5. No logs appearing in Kibana**
```powershell
# Check Winlogbeat service
Get-Service winlogbeat

# Check Logstash logs
docker compose logs logstash

# Verify Winlogbeat configuration
Get-Content "C:\Program Files\winlogbeat\winlogbeat.yml"
```

### Health Checks

```powershell
# Check Elasticsearch
Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health"

# Check Kibana
Invoke-RestMethod -Uri "http://localhost:5601/api/status"

# Check Grafana
Invoke-RestMethod -Uri "http://localhost:3000/api/health"

# Check for Winlogbeat indices
Invoke-RestMethod -Uri "http://localhost:9200/_cat/indices/winlogbeat*"
```

## 📊 Using the Stack

### Kibana (Log Analysis)

1. **Access Kibana**: http://localhost:5601
2. **Discover Tab**: View real-time Windows Event Logs
3. **Index Pattern**: `winlogbeat-*` (pre-configured)
4. **Time Range**: Adjust to view historical data
5. **Filters**: Filter by log level, event ID, source, etc.

### Grafana (Dashboards)

1. **Access Grafana**: http://localhost:3000
2. **Login**: admin / (password from `.env` file)
3. **Datasource**: Elasticsearch (pre-configured)
4. **Dashboards**: Import or create custom dashboards
5. **Alerts**: Set up alerting for critical events

### Common Queries

**Kibana KQL Examples**:
```
# Security events
winlog.event_id: 4625  # Failed logons

# Application errors
winlog.event_data.Level: "Error"

# System events from last hour
@timestamp >= now-1h and winlog.channel: "System"
```

## 🚨 Security Considerations

⚠️ **This configuration is for LOCAL DEVELOPMENT/TESTING only**

- **No authentication** on Elasticsearch and Kibana
- **HTTP only** - no SSL/TLS encryption
- **Default passwords** in `.env.example`

### For Production Use:
- Enable Elasticsearch security (`xpack.security.enabled=true`)
- Configure SSL/TLS certificates
- Change default passwords
- Implement proper authentication
- Network segmentation and firewall rules
- Regular security updates

## 🔄 Customization

### Adding More Event Logs

Edit `winlogbeat/winlogbeat.template.yml`:

```yaml
winlogbeat.event_logs:
  - name: Application
  - name: System  
  - name: Security
  - name: Microsoft-Windows-PowerShell/Operational
  - name: Microsoft-Windows-Sysmon/Operational
```

### Custom Grafana Dashboards

1. Create dashboard JSON files in `grafana/dashboards/`
2. Restart Grafana container: `docker compose restart grafana`
3. Dashboards will be auto-imported

### Logstash Pipeline Customization

Edit `logstash/pipeline/winlog.conf` to:
- Add custom parsing rules
- Enrich log data
- Filter specific events
- Route to different indices

## 📚 Documentation Links

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/8.11/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/8.11/index.html)
- [Logstash Documentation](https://www.elastic.co/guide/en/logstash/8.11/index.html)
- [Winlogbeat Documentation](https://www.elastic.co/guide/en/beats/winlogbeat/8.15/index.html)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Elastic Stack team for the ELK ecosystem
- Grafana Labs for the visualization platform
- Docker team for containerization technology
- Microsoft for Windows Event Logging capabilities

## 📞 Support

For issues and support:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Search existing [GitHub Issues](https://github.com/yourusername/windows-elk-grafana-stack/issues)
3. Create a new issue with:
   - System specifications
   - Docker Desktop version
   - Error logs (`docker compose logs`)
   - PowerShell execution output

## 📋 Version Information

- **Elastic Stack**: 8.11.2
- **Winlogbeat**: 8.15.1
- **Grafana**: Latest
- **Tested on**: Windows 10/11, Windows Server 2019/2022

---

**Made with ❤️ for Windows system administrators and DevOps engineers**


*Simple, effective, and ready to deploy Windows Event Log monitoring*
