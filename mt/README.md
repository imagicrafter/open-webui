# Multi-Tenant Open WebUI

## Overview

This directory contains a complete **multi-tenant deployment system** for [Open WebUI](https://github.com/open-webui/open-webui) - an extensible, self-hosted AI chat interface supporting multiple LLM providers (Ollama, OpenAI, Anthropic, and more).

### Purpose

The **mt/** (multi-tenant) system extends the Open WebUI fork with production-ready infrastructure for deploying and managing **multiple isolated Open WebUI instances** on a single server or across multiple hosts. This enables SaaS-style deployments, client-specific installations, and high-availability configurations.

### Key Features

**🔐 Complete Isolation**
- Each client gets their own Docker container with dedicated resources
- Isolated data volumes (separate chat history, settings, user databases)
- Custom domains and branding per deployment
- dedicated SQLite database in the Open WebUI container
- Sync capabable with a dedicated schema on PostgreSQL/Supabase cloud

**🚀 Production-Ready Infrastructure**
- **Dual nginx Modes**: HOST nginx (systemd service, production-ready) + Containerized nginx (experimental)
- **Automated SSL**: Let's Encrypt certificate generation with staging and production options
- **OAuth Integration**: Google OAuth with domain restrictions, ready out-of-the-box
- **Client Manager**: Interactive menu-driven management tool for infrastructure deployment and maintenance operations
- **Quick Setup**: Single-command server provisioning with automated configuration

**📊 Database Flexibility**
- **SQLite**: Default local database for simple deployments
- **PostgreSQL/Supabase**: Sync capable with Cloud-hosted databases for backups and future potential for scalability and multi-instance sharing
- **One-Click Migration**: Built-in SQLite → PostgreSQL migration with automatic backups and rollback
- **Configuration Viewer**: Inspect database settings for any deployment

**⚡ High Availability & Sync (NEW)**
- **Dual-Node Sync System**: Primary/secondary containers with automatic leader election
- **SQLite + Supabase Sync**: One-way synchronization (Phase 1) with bidirectional support planned
- **Conflict Resolution**: 5 configurable strategies for handling data conflicts
- **Automatic Failover**: <35 seconds failover time with Prometheus monitoring
- **IPv6 Auto-Configuration**: Optimal Supabase connectivity on Digital Ocean

**🔧 Developer-Friendly**
- **Interactive CLI**: client-manager.sh provides menu-driven interface for all operations
- **Template Scripts**: Quickly spin up new clients with pre-configured settings
- **Automated Testing**: Comprehensive test suite for security, failover, and integration validation
- **Documentation**: Extensive guides for setup, migration, troubleshooting, and monitoring

### What This Fork Adds to Open WebUI

This fork maintains **full compatibility** with upstream Open WebUI while adding:

1. **mt/** Directory Structure:
   - `client-manager.sh` - Central management tool for all deployments
   - `start-template.sh` - Parameterized client deployment script
   - `DB_MIGRATION/` - Complete SQLite → PostgreSQL migration system
   - `SYNC/` - High-availability sync system with leader election
   - `nginx-container/` - Containerized nginx deployment with automated SSL
   - `setup/` - Quick server provisioning and configuration
   - `tests/` - Testing and certification suite

2. **Custom Branding Support**:
   - QuantaBase branding in `assets/logos/`
   - Custom favicon and logos throughout the interface
   - Configurable WEBUI_NAME per deployment

3. **Enhanced OAuth**:
   - Pre-configured Google OAuth integration
   - Domain-based access restrictions
   - Automated redirect URI management

4. **Production Deployment Automation**:
   - Digital Ocean optimized quick-setup
   - Automated user provisioning (qbmgr)
   - Security-hardened configurations
   - Automated client-manager launch on login

### Use Cases

**💼 SaaS Providers**
- Deploy isolated instances for multiple customers on shared infrastructure
- Automated provisioning and management
- Database migration paths for scaling

**🏢 Enterprise Deployments**
- Department-specific instances with separate data
- High-availability configurations with failover
- Centralized monitoring and management

**🧪 Development & Testing**
- Quickly spin up test environments
- Database migration testing with staging certificates
- Multi-instance testing with shared databases

**🌐 Agency Deployments**
- Client-branded instances with custom domains
- Separate databases per client for data isolation
- Managed hosting with automated backups

## Getting Started

### Step 1: Create Digital Ocean Droplet

1. **Log in to Digital Ocean** and click "Create" → "Droplets"

2. **Choose Region** - Select the region closest to your users

3. **Choose Image** - **IMPORTANT**: Select "Marketplace" → Search for "Docker on Ubuntu"
   - This provides a pre-configured Ubuntu environment with Docker installed

4. **Choose Size** - Select based on number of client deployments:
   - **Droplet Type**: Regular SSD
   - **1-2 clients**: 2GB RAM / 1 vCPU / 50GB SSD ($12/month)
   - **3-4 clients**: 4GB RAM / 2 vCPUs / 80GB SSD ($24/month)
   - **5-8 clients**: 8GB RAM / 4 vCPUs / 160GB SSD ($48/month)

   > 📝 See **System Requirements** section at the end for detailed memory calculations and scaling guidelines.

5. **Add SSH Key** (Recommended)
   - Click "New SSH Key" and paste your public key
   - To get your public key: `cat ~/.ssh/id_rsa.pub` (or `~/.ssh/id_ed25519.pub`)
   - Adding your key during creation is less error-prone than providing it to the script later

6. **Advanced Options**
   - ✅ **Enable Monitoring** - Provides CPU, bandwidth, and disk metrics
   - ✅ **Enable IPv6** - **REQUIRED** for syncing with Supabase

7. **Finalize and Create**
   - Choose a hostname (e.g., `openwebui-prod-01`)
   - Click "Create Droplet"
   - Note the droplet's IP address once it's created

### Step 2: Run Quick Setup

SSH to your droplet as root and run the setup command:

**Option 1: Auto-copy SSH key from root** (if you added SSH key during droplet creation)
```bash
curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash -s -- "" "production"
```

**Option 2: Provide SSH key manually**
```bash
curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash -s -- "" "test"
```

The quick-setup script automates server provisioning, user creation, security configuration, and deployment setup. For complete details on what gets installed, security hardening steps, and troubleshooting, see **[mt/setup/README.md](setup/README.md)**.

**What's the difference between "test" and "production"?**

| Server Type | Git Branch | Docker Image | When to Use |
|-------------|------------|--------------|-------------|
| `test` | `main` | `ghcr.io/imagicrafter/open-webui:main` | Development, testing new features |
| `production` | `release` | `ghcr.io/imagicrafter/open-webui:release` | Client deployments, production use |

The setup script automatically:
- Clones the appropriate git branch
- Sets `OPENWEBUI_IMAGE_TAG` environment variable in `~/.bashrc`
- All deployments on that server will automatically use the correct Docker image

**No manual configuration needed!** The deployment scripts (`start-template.sh`, `client-manager.sh`) read this variable automatically.

### Step 3: Login as qbmgr

After setup completes:

```bash
exit  # Exit root session
ssh qbmgr@YOUR_DROPLET_IP
```

The **client-manager will start automatically** and show the main menu.

### Step 4: Deploy nginx and Create Clients

From the client-manager menu:
1. **Option 6**: Manage nginx Installation → Install nginx on HOST
2. **Option 3**: Create New Deployment
3. **Option 5**: Generate nginx Configuration (automated config + SSL setup)
4. Follow the SSL setup wizard

That's it! Your multi-tenant Open WebUI is now running.

### Troubleshooting Setup

#### Script fails to run

**Check the error message:**
- `Invalid SSH key format`: Ensure you copied your **public** key (starts with `ssh-rsa` or `ssh-ed25519`)
- `Permission denied`: Make sure you're logged in as root when running the setup

**Re-run the setup:**
```bash
# The script is idempotent - safe to run multiple times
curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash
```

#### Can't SSH as qbmgr

**Verify the key was added:**
```bash
# As root
cat /home/qbmgr/.ssh/authorized_keys
```

**Check permissions:**
```bash
# As root
ls -la /home/qbmgr/.ssh/
# Should show: drwx------ (700) for directory
#              -rw------- (600) for authorized_keys
```

**Fix permissions if needed:**
```bash
# As root
chmod 700 /home/qbmgr/.ssh
chmod 600 /home/qbmgr/.ssh/authorized_keys
chown -R qbmgr:qbmgr /home/qbmgr/.ssh
```

#### Docker permission denied

**Logout and login again** to activate docker group membership:
```bash
exit
ssh qbmgr@YOUR_DROPLET_IP
```

**Or manually activate the group:**
```bash
newgrp docker
docker ps  # Should work now
```

#### Client-manager doesn't auto-start

**Check .bash_profile exists:**
```bash
cat ~/.bash_profile
```

**Manually start client-manager:**
```bash
cd ~/open-webui/mt
./client-manager.sh
```

---

## Database Migration Feature

The client manager includes built-in database migration capabilities:
- **Automatic detection** of current database type (SQLite or PostgreSQL)
- **One-click migration** from SQLite to Supabase PostgreSQL
- **Zero data loss** with automatic backups and rollback
- **Configuration viewer** for PostgreSQL deployments

Perfect for scaling from local development to cloud-hosted production databases.

**📖 [Complete Migration Documentation →](DB_MIGRATION/README.md)**

The DB_MIGRATION folder contains comprehensive documentation covering:
- Step-by-step migration process
- Security posture explanation (why no RLS, public schema)
- Rollback procedures
- Troubleshooting guide
- Migration scripts and helper functions

## High Availability Sync System (NEW - Phase 1)

**⭐ NEW**: The `SYNC/` directory contains a production-ready **SQLite + Supabase Sync System** with high availability:

**Key Features**:
- **Dual sync containers** (primary/secondary) with automatic leader election
- **One-way sync** SQLite → Supabase (Phase 1)
- **Automated conflict resolution** with 5 configurable strategies
- **Supabase as authoritative state** with local caching (5-min TTL)
- **High availability** with automatic failover (<35 seconds)
- **Comprehensive monitoring** via Prometheus metrics
- **IPv6 auto-configuration** for optimal Supabase connectivity

**Architecture**:
- **Leader Election**: PostgreSQL atomic operations (no external dependencies)
- **State Management**: Cache-aside pattern with cluster synchronization
- **Security**: Restricted database roles, Row Level Security (RLS)
- **Deployment**: Automated with `deploy-sync-cluster.sh`

**📖 [Complete Sync System Documentation →](SYNC/README.md)**

The SYNC folder includes:
- Complete architectural overview and design patterns
- **Automatic IPv6 detection and configuration** (Digital Ocean supported)
- FastAPI application with REST API and health checks
- Deployment automation with pre-flight validation
- Conflict resolution strategies and configuration
- Monitoring and troubleshooting guides
- Phase 2 roadmap (bidirectional sync, cross-host migration)

**Quick Start**:
```bash
cd mt/SYNC
./scripts/deploy-sync-cluster.sh
```

See [SYNC/README.md](SYNC/README.md) for detailed documentation including IPv6 setup requirements.

## Testing & Certification

### Testing Suite

**Location**: `mt/tests/`

The testing suite validates all mt/ features before production release. Tests cover:
- **Security validation**: Permission and access control tests
- **HA failover testing**: High availability and leader election
- **Integration tests**: Component interaction validation
- **Performance tests**: Load and latency benchmarks

**📖 [Complete Testing Documentation →](tests/README.md)**

**Available Tests**:
- ✅ `sync-security-validation.py` - SYNC security validation (13 tests, all passing)
- ⏳ `sync-ha-failover.sh` - HA failover tests (manual testing complete, script pending)
- 🔲 `sync-conflict-resolution.sh` - Conflict resolution tests (planned)
- 🔲 `sync-state-authority.sh` - State management tests (planned)

**Quick Test Execution**:
```bash
# Run security validation tests
cd mt/tests
source ../SYNC/.credentials
docker exec -i -e SYNC_URL="$SYNC_URL" -e ADMIN_URL="$ADMIN_URL" \
    openwebui-sync-node-a python3 - < sync-security-validation.py
```

**Future: Automated Certification**
```bash
# Run full certification suite (future)
cd mt/tests
./run-certification.sh
```

This will validate all components before production deployment and generate comprehensive test reports.

## Monitoring & Observability

### Current State

The sync containers **already expose Prometheus metrics** on their `/metrics` endpoints:

- **Node A**: `http://localhost:9443/metrics`
- **Node B**: `http://localhost:9444/metrics`

**Available Metrics** (automatically instrumented):

| Category | Metrics | Description |
|----------|---------|-------------|
| **Leader Election** | `sync_is_leader`<br>`sync_leader_election_attempts_total`<br>`sync_leader_election_successes_total`<br>`sync_leader_lease_expires_timestamp` | Leadership status, election attempts, lease expiration |
| **Heartbeats** | `sync_heartbeat_failures_total`<br>`sync_container_uptime_seconds` | Heartbeat failures, container uptime |
| **Sync Operations** | `sync_operations_total{status}`<br>`sync_operation_duration_seconds`<br>`sync_rows_synced_total` | Sync job metrics, duration histograms, row counts |
| **Conflicts** | `sync_conflicts_detected_total`<br>`sync_conflicts_resolved_total{strategy}` | Conflict detection and resolution by strategy |
| **Failover** | `sync_failover_events_total` | Leadership change events |

### Centralized Monitoring Setup (Planned)

**Location**: `mt/monitoring/` (not yet implemented)

The centralized monitoring stack will track:
- ✅ All sync clusters across different hosts
- ✅ Client deployment health and status
- ✅ Future mt/ services (client-manager metrics, etc.)

**Planned Architecture**:
```
mt/monitoring/
├── docker-compose.yml          # Prometheus + Grafana stack
├── prometheus/
│   ├── prometheus.yml          # Multi-cluster scrape config
│   └── alerts.yml              # Alert rules for failures
└── grafana/
    └── dashboards/
        ├── sync-clusters.json  # Multi-cluster overview
        └── mt-overview.json    # Overall mt/ stack health
```

**Access** (when deployed):
- **Grafana**: `http://localhost:3000` (dashboards)
- **Prometheus**: `http://localhost:9090` (raw metrics)

**Dashboards will include**:
- Leadership status over time (which node is leader)
- Heartbeat freshness graphs
- Failover events timeline
- Sync operation success/failure rates
- Conflict resolution statistics
- Per-cluster and cross-cluster views

### Manual Monitoring (Current)

Until centralized monitoring is deployed, monitor clusters via:

**1. Health API Endpoints**:
```bash
# Check Node A
curl http://localhost:9443/health | jq

# Check Node B
curl http://localhost:9444/health | jq
```

**2. Database Views**:
```sql
-- Cluster health overview
SELECT * FROM sync_metadata.v_cluster_health;

-- Active sync jobs
SELECT * FROM sync_metadata.v_active_sync_jobs;

-- Recent conflicts
SELECT * FROM sync_metadata.v_recent_conflicts;
```

**3. Raw Metrics**:
```bash
# View all metrics from Node A
curl http://localhost:9443/metrics

# Filter specific metrics
curl http://localhost:9443/metrics | grep sync_is_leader
```

### Setting Up Monitoring (Future)

When the centralized monitoring stack is ready:

```bash
# Deploy monitoring infrastructure
cd mt/monitoring
docker compose up -d

# Access Grafana
open http://localhost:3000
# Default login: admin/admin

# Add new cluster to monitoring
# Edit prometheus/prometheus.yml
# Add scrape target for new cluster endpoints
docker compose restart prometheus
```

### Adding Clusters to Monitoring

To monitor a new sync cluster:

1. **Deploy sync cluster** on new host
2. **Get metrics endpoints** (`http://HOST:9443/metrics`, `http://HOST:9444/metrics`)
3. **Update Prometheus config** to scrape new endpoints
4. **Verify** in Grafana dashboards

### Troubleshooting Monitoring

**Metrics not appearing?**
- Verify containers are running: `docker ps | grep sync-node`
- Check metrics endpoint: `curl http://localhost:9443/metrics`
- Review container logs: `docker logs openwebui-sync-node-a`

**Stale heartbeat warnings?**
- Fixed in latest version with stable `host_id` across restarts
- View real-time status: `SELECT * FROM sync_metadata.v_cluster_health;`

### Archon Tasks for Monitoring Implementation

The following tasks are tracked in Archon for implementing centralized monitoring:

1. **Design monitoring architecture** - Decide on federation vs single instance
2. **Create Prometheus configuration** - Scrape configs and alert rules
3. **Create Grafana dashboards** - Multi-cluster views and drill-downs
4. **Create docker-compose** - Monitoring stack deployment

See Archon project `038661b1-7e1c-40d0-b4f9-950db24c2a3f` for task details.

## Quick Start

### Start Pre-configured Clients
```bash
# Start ACME Corp instance (port 8081)
./start-acme-corp.sh

# Start Beta Client instance (port 8082)
./start-beta-client.sh
```

### Start Custom Client
```bash
# Usage: ./start-template.sh CLIENT_NAME PORT DOMAIN CONTAINER_NAME FQDN [OAUTH_DOMAINS] [WEBUI_SECRET_KEY]
./start-template.sh xyz-corp 8083 xyz.yourdomain.com openwebui-xyz-corp xyz.yourdomain.com
```

### Manage All Clients
```bash
# Show help and available commands
./client-manager.sh

# List all client containers
./client-manager.sh list

# Stop all client containers
./client-manager.sh stop

# Start all stopped client containers
./client-manager.sh start

# View logs for specific client
./client-manager.sh logs acme-corp
```

### Migrate Database to PostgreSQL
```bash
# Access interactive client manager
./client-manager.sh

# Select "4) Manage Client Deployment"
# Choose your client
# Select "8) Migrate to Supabase/PostgreSQL"

# The wizard will guide you through:
# - Entering Supabase credentials
# - Testing connectivity
# - Creating backups
# - Migrating data
# - Switching to PostgreSQL

# See "Database Migration" section for full details
```

## File Structure

```
mt/
├── README.md                    # This file
├── start-template.sh            # Template for creating client instances
├── start-acme-corp.sh           # Pre-configured ACME Corp launcher
├── start-beta-client.sh         # Pre-configured Beta Client launcher
├── client-manager.sh            # Multi-client management tool
├── setup/                       # ⭐ Quick server provisioning system
│   ├── README.md                # Complete setup documentation
│   └── quick-setup.sh           # Automated server setup script
├── nginx/                       # ⭐ nginx deployment planning and documentation
│   └── DEV_PLAN_FOR_NGINX_GET_WELL.md  # Implementation plan for nginx integration
├── DB_MIGRATION/                # Database migration system (SQLite → PostgreSQL)
│   ├── README.md                # Complete migration documentation
│   ├── db-migration-helper.sh   # Migration utility functions
│   └── migrate-db.py            # Python data migration script
├── SYNC/                        # ⭐ SQLite + Supabase Sync System (Phase 1)
│   ├── README.md                # Complete sync system documentation
│   ├── python/                  # FastAPI application and sync modules
│   ├── scripts/                 # Deployment and sync automation
│   ├── docker/                  # Container infrastructure
│   └── config/                  # Configuration templates
├── tests/                       # ⭐ Testing & Certification Suite
│   ├── README.md                # Testing methodology and documentation
│   ├── sync-security-validation.py  # SYNC security tests (✅ all passing)
│   └── run-certification.sh     # Batch test runner (future)
└── nginx-container/             # ⭐ Containerized nginx for Multi-Tenant Setup
    ├── README.md                # Complete nginx container documentation
    ├── MANUAL_SSL_SETUP.md      # SSL troubleshooting guide
    ├── deploy-nginx-container.sh             # Deploy nginx container
    ├── create-ssl-options.sh                 # Generate SSL config files
    ├── nginx-template-containerized.conf     # HTTPS template (with SSL)
    └── nginx-template-containerized-http-only.conf  # HTTP-only template (pre-SSL)
```

## Container Naming Convention

| Client | Container Name | Port | Domain |
|--------|---------------|------|---------|
| ACME Corp | `openwebui-acme-corp` | 8081 | acme.yourdomain.com |
| Beta Client | `openwebui-beta-client` | 8082 | beta.yourdomain.com |
| Custom | `openwebui-CLIENT_NAME` | Custom | Custom |

## Volume Naming Convention

Each client gets an isolated Docker volume:
- `openwebui-acme-corp-data`
- `openwebui-beta-client-data`
- `openwebui-CLIENT_NAME-data`

## Adding New Clients

### Method 1: Use Template Script
```bash
./start-template.sh new-client 8084 newclient.yourdomain.com openwebui-new-client newclient.yourdomain.com
```

### Method 2: Create Dedicated Script
1. Copy an existing client script:
   ```bash
   cp start-acme-corp.sh start-new-client.sh
   ```

2. Edit the new script to change the client name, port, and domain:
   ```bash
   ${SCRIPT_DIR}/start-template.sh new-client 8084 newclient.yourdomain.com openwebui-new-client newclient.yourdomain.com
   ```

3. Make it executable:
   ```bash
   chmod +x start-new-client.sh
   ```

## Individual Container Management

```bash
# Stop specific client
docker stop openwebui-CLIENT_NAME

# Start specific client
docker start openwebui-CLIENT_NAME

# Restart specific client
docker restart openwebui-CLIENT_NAME

# View logs for specific client
docker logs -f openwebui-CLIENT_NAME

# Remove client (CAUTION: This deletes the container but preserves data volume)
docker stop openwebui-CLIENT_NAME && docker rm openwebui-CLIENT_NAME
```

## Port Management

**Used Ports:**
- 8081: ACME Corp
- 8082: Beta Client

**Available Ports:**
- 8083-8099: Available for new clients

**Port Conflict Check:**
```bash
# Check what ports are in use
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Check specific port
sudo lsof -i :8083
```

## nginx Configuration & HTTPS Setup

### HOST nginx (Recommended for Production)

**For production deployments with automated SSL setup**, use HOST nginx (systemd service):

```bash
# Access interactive client manager
./client-manager.sh

# Choose option 6: "Manage nginx Installation"
# Select 1: "Install nginx on HOST (Production - Recommended)"
# Then create deployments and configure with automated HTTPS
```

The client manager provides:
- **Automated SSL certificate generation** with Let's Encrypt (production + staging)
- **Automated config installation** (no manual copy/paste)
- **Interactive SSL wizard** with rate limit warnings
- **Firewall auto-configuration** with fallback logic
- **nginx test and reload** automation

### Containerized nginx (Experimental)

**For testing containerized nginx** (has known issues with function pipes):

```bash
cd mt/nginx-container
sudo ./deploy-nginx-container.sh

# Then use client-manager.sh to configure clients
cd ..
./client-manager.sh
# Choose option 2: "Manage nginx Container"
```

**📖 [Complete nginx Container Documentation →](nginx-container/README.md)**

The nginx-container folder includes:
- **Container-to-container networking** for better security
- **Pre-built configuration templates** for HTTP and HTTPS
- **Comprehensive troubleshooting guide** (MANUAL_SSL_SETUP.md)
- ⚠️ **Known Issues**: Function pipe saves may fail (use HOST nginx for production)

## OAuth Configuration

### QuantaBase Google Cloud Project

**Google Cloud Console:** https://console.cloud.google.com/apis/credentials?hl=en&project=quantabase
**OAuth 2.0 Client ID:** `Open WebUI`
**Client ID:** `1063776054060-2fa0vn14b7ahi1tmfk49cuio44goosc1.apps.googleusercontent.com`

### Shared OAuth Configuration

All QuantaBase client instances share the same Google OAuth configuration:

- **Domain Restriction:** `martins.net` (only @martins.net email addresses can sign in)
- **Authorized JavaScript Origins:** Must include each client's domain
- **Authorized Redirect URIs:** Must include each client's callback URL

### Adding New Client Domains

When creating a new client deployment, add these URLs to the OAuth configuration:

**For Development (localhost):**
```
Authorized JavaScript Origins:
- http://127.0.0.1:PORT
- http://localhost:PORT

Authorized Redirect URIs:
- http://127.0.0.1:PORT/oauth/google/callback
- http://localhost:PORT/oauth/google/callback
```

**For Production:**
```
Authorized JavaScript Origins:
- https://CLIENT_NAME.yourdomain.com

Authorized Redirect URIs:
- https://CLIENT_NAME.yourdomain.com/oauth/google/callback
```

### Current Configured Clients

| Client | Development | Production |
|--------|------------|------------|
| Main Instance | http://127.0.0.1:8080 | https://yourdomain.com |
| imagicrafter | http://127.0.0.1:8081 | https://imagicrafter.yourdomain.com |

### OAuth Configuration Steps

1. **Access Google Cloud Console:** https://console.cloud.google.com/apis/credentials?hl=en&project=quantabase
2. **Select "Open WebUI" OAuth 2.0 Client ID**
3. **Add new Authorized JavaScript Origins** for the client domain
4. **Add new Authorized Redirect URIs** for the OAuth callback
5. **Save changes**
6. **Test authentication** at the client URL

## Source Code Update Process

This system uses a custom fork of Open WebUI with QuantaBase branding. Follow this process to update to the latest Open WebUI version while preserving custom modifications.

### Repository Setup

**Custom Fork:** `https://github.com/imagicrafter/open-webui`
**Container Image:** `ghcr.io/imagicrafter/open-webui:main`
**Upstream:** `https://github.com/open-webui/open-webui`

### Your Customizations (What to Preserve)

The following files/directories contain your QuantaBase customizations:

**✅ Committed Custom Files:**
- `assets/logos/` - Custom QuantaBase branding assets
- `backend/open_webui/static/favicon.png` - Replaced favicon
- `backend/open_webui/static/logo.png` - Replaced logo
- `backend/open_webui/static/swagger-ui/favicon.png` - API docs favicon
- `static/favicon.png` and `static/static/` - Additional static file replacements
- `favicon_backup/` - Backup of original files
- `.claude/` - Claude Code session files
- `docker-start.md` - Custom documentation

**⚠️ Local-Only Files (Need to commit):**
- `mt/` - Multi-tenant client management system
- `start.sh` - Enhanced QuantaBase startup script

### Update Workflow (Branching Strategy)

This strategy ensures your customizations are never lost during updates:

#### 1. Prepare for Update

```bash
# Navigate to your local fork
cd /path/to/your/open-webui

# Ensure upstream remote exists
git remote add upstream https://github.com/open-webui/open-webui.git || true

# Commit any local changes first
git add mt/ start.sh
git commit -m "Add multi-tenant system and enhanced start script"
git push origin main
```

#### 2. Create Branching Structure

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Create quantabase-branded branch (preserves all your customizations)
git checkout -b quantabase-branded
git push origin quantabase-branded

# Create update branch from quantabase-branded
git checkout -b quantabase-update
```

#### 3. Pull Upstream Changes

```bash
# Fetch latest from upstream
git fetch upstream

# Merge upstream changes into update branch
git merge upstream/main

# Handle merge conflicts:
# - Choose YOUR version for all files in "Your Customizations" list above
# - Accept UPSTREAM version for core Open WebUI functionality
# - Manually merge any files that need both changes
```

#### 4. Preserve Your Customizations

If conflicts occur with your custom files, resolve them like this:

```bash
# For custom branding files, keep your version:
git checkout --ours assets/logos/
git checkout --ours backend/open_webui/static/favicon.png
git checkout --ours backend/open_webui/static/logo.png
# ... repeat for all custom files

# For core functionality, accept upstream:
git checkout --theirs src/lib/components/
git checkout --theirs backend/open_webui/routers/
# ... etc for core files

# Commit the resolution
git add .
git commit -m "Merge upstream $(date +%Y-%m-%d) - preserved QuantaBase customizations"
```

#### 5. Merge Back to Branded Branch

```bash
# Merge update branch into quantabase-branded
git checkout quantabase-branded
git merge quantabase-update

# Push updated branded branch
git push origin quantabase-branded
```

#### 6. Build and Test Locally

```bash
# Still on quantabase-update branch
# Build your updated image locally
docker build -t ghcr.io/imagicrafter/open-webui:test .

# Test with a temporary container
docker run -d --name test-openwebui -p 8090:8080 \
  -e GOOGLE_CLIENT_ID=your_client_id \
  -e GOOGLE_CLIENT_SECRET=your_secret \
  -e GOOGLE_REDIRECT_URI=http://127.0.0.1:8090/oauth/google/callback \
  -e ENABLE_OAUTH_SIGNUP=true \
  -e OAUTH_ALLOWED_DOMAINS=martins.net \
  -e WEBUI_NAME="QuantaBase Test" \
  ghcr.io/imagicrafter/open-webui:test

# Test checklist:
# ✅ OAuth login works
# ✅ QuantaBase branding appears correctly
# ✅ Core Open WebUI features function
# ✅ Multi-tenant scripts work (if testing locally)

# Clean up test container
docker stop test-openwebui && docker rm test-openwebui
```

#### 7. Merge to Main Branch

```bash
# If tests pass, merge quantabase-update into main
git checkout main
git merge quantabase-update
git push origin main

# Tag the release
git tag -a v$(date +%Y.%m.%d) -m "Update to latest Open WebUI $(date +%Y-%m-%d)"
git push origin --tags

# Clean up update branch
git branch -d quantabase-update
git push origin --delete quantabase-update
```

#### 8. Wait for GitHub Actions Build

After pushing to main, **GitHub Actions automatically builds your custom image**:

- 🔄 **Monitor build**: https://github.com/imagicrafter/open-webui/actions
- ⏱️ **Build time**: ~15-20 minutes
- 📦 **Result**: `ghcr.io/imagicrafter/open-webui:main` with QuantaBase branding

**⚠️ Important**: Wait for build completion before proceeding to production deployment.

#### 9. Deploy to Production (Manual Process)

**GitHub Actions does NOT auto-deploy to your server.** You manually control when production updates:

```bash
# SSH to production server
ssh user@your-production-server

# Navigate to deployment directory
cd /path/to/open-webui

# Pull latest code (for scripts and configurations)
git pull origin main

# Pull the new custom image that GitHub Actions just built
docker pull ghcr.io/imagicrafter/open-webui:main
```

#### 10. Restart Client Containers

```bash
# Update all client deployments with new image
./mt/client-manager.sh stop
docker ps -a --filter "name=openwebui-" --format "{{.Names}}" | xargs docker rm
./mt/client-manager.sh start

# Verify all clients are running with updated image
./mt/client-manager.sh list
docker images ghcr.io/imagicrafter/open-webui
```

### Deployment Flow Summary

**🔄 What's Automated:**
- ✅ **Image Building**: GitHub Actions builds custom image on push to main
- ✅ **Image Publishing**: Pushes to `ghcr.io/imagicrafter/open-webui:main`
- ✅ **Multi-platform**: Supports both amd64 and arm64 architectures

**👤 What You Control:**
- ✅ **When to Deploy**: You decide when to update production
- ✅ **Which Clients**: Choose which clients to update
- ✅ **Rollback**: Keep previous images for quick rollback if needed

**🚫 What's NOT Automated:**
- ❌ **Production Deployment**: No automatic server access (security)
- ❌ **Client Updates**: No automatic container restarts
- ❌ **Configuration Changes**: Manual git pull required

This gives you **maximum control** over production deployments while automating the heavy lifting of image builds.

### Rollback Process

If an update causes issues:

```bash
# Check recent image tags
docker images ghcr.io/imagicrafter/open-webui

# Use a previous tag
docker tag ghcr.io/imagicrafter/open-webui:v2024.01.15 ghcr.io/imagicrafter/open-webui:main

# Restart clients with previous version
./mt/client-manager.sh stop
docker ps -a --filter "name=openwebui-" --format "{{.Names}}" | xargs docker rm
./mt/client-manager.sh start
```

### Custom Branding Checklist

When updating, ensure these custom elements are preserved:

- [ ] QuantaBase logos in `assets/logos/`
- [ ] Custom favicon files
- [ ] Environment variable configurations
- [ ] OAuth settings and domain restrictions
- [ ] Any custom styling or themes

## Updates and Maintenance

### Image Updates (New Open WebUI Version)

To update a client to the latest Open WebUI version while preserving all data:

```bash
# Stop and remove container (keeps volume and data)
docker stop openwebui-CLIENT_NAME && docker rm openwebui-CLIENT_NAME

# Pull latest image
docker pull ghcr.io/imagicrafter/open-webui:main

# Recreate with new image (data automatically preserved)
./start-template.sh CLIENT_NAME PORT DOMAIN CONTAINER_NAME FQDN
```

**Example - Update imagicrafter client:**
```bash
docker stop openwebui-imagicrafter && docker rm openwebui-imagicrafter
docker pull ghcr.io/imagicrafter/open-webui:main
./start-template.sh imagicrafter 8081 imagicrafter.yourdomain.com openwebui-imagicrafter imagicrafter.yourdomain.com
```

### Configuration Updates

To update environment variables or settings:

```bash
# Stop and remove container
docker stop openwebui-CLIENT_NAME && docker rm openwebui-CLIENT_NAME

# Recreate with new configuration (data preserved)
./start-template.sh CLIENT_NAME PORT DOMAIN CONTAINER_NAME FQDN
```

### Fresh Start (Delete All Data)

⚠️ **WARNING: This permanently deletes all client data**

```bash
# Stop and remove container AND volume
docker stop openwebui-CLIENT_NAME && docker rm openwebui-CLIENT_NAME
docker volume rm openwebui-CLIENT_NAME-data

# Recreate from scratch
./start-template.sh CLIENT_NAME PORT DOMAIN CONTAINER_NAME FQDN
```

### Bulk Updates

Update all clients to latest image:

```bash
# Stop all clients
./client-manager.sh stop

# Pull latest image
docker pull ghcr.io/imagicrafter/open-webui:main

# Remove all containers (keeps volumes)
docker ps -a --filter "name=openwebui-" --format "{{.Names}}" | xargs docker rm

# Restart all clients (they'll use the new image)
./client-manager.sh start
```

### Volume Management

```bash
# List all client volumes
docker volume ls | grep openwebui

# Check volume disk usage
docker system df -v | grep openwebui

# Remove unused volumes (DANGER - only if you're sure)
docker volume prune
```

## Data Backup

Each client's data is stored in a named Docker volume:

```bash
# List all client volumes
docker volume ls | grep openwebui

# Backup client data
docker run --rm -v openwebui-CLIENT_NAME-data:/data -v $(pwd):/backup alpine tar czf /backup/CLIENT_NAME-backup.tar.gz -C /data .

# Restore client data
docker run --rm -v openwebui-CLIENT_NAME-data:/data -v $(pwd):/backup alpine tar xzf /backup/CLIENT_NAME-backup.tar.gz -C /data

# Backup all client data
for volume in $(docker volume ls --filter name=openwebui- --format "{{.Name}}"); do
  client=$(echo $volume | sed 's/openwebui-//' | sed 's/-data//')
  docker run --rm -v $volume:/data -v $(pwd):/backup alpine tar czf /backup/${client}-backup-$(date +%Y%m%d).tar.gz -C /data .
done
```

## Database Migration

### Overview

Open WebUI supports two database backends:
- **SQLite** (default): Local database stored in the container volume
- **PostgreSQL/Supabase**: Cloud-hosted PostgreSQL for scalability and multi-instance deployments

The client manager includes built-in migration capabilities to seamlessly migrate from SQLite to Supabase PostgreSQL.

### When to Migrate to PostgreSQL

Consider migrating to PostgreSQL/Supabase when you need:
- **Remote access** to your database for backups and analysis
- **Scalability** beyond local storage limits
- **Multi-instance deployments** sharing the same database
- **Better performance** for large datasets
- **Cloud-based backups** and disaster recovery

**📖 [Complete Migration Documentation →](DB_MIGRATION/README.md)** - Includes prerequisites, step-by-step process, troubleshooting, rollback procedures, and security considerations.

## Troubleshooting

### Container Won't Start
```bash
# Check if container name already exists
docker ps -a | grep openwebui-CLIENT_NAME

# Check port conflicts
sudo lsof -i :PORT_NUMBER

# Check logs
docker logs openwebui-CLIENT_NAME
```

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x *.sh
```

### OAuth Issues
1. Verify redirect URI in Google Cloud Console
2. Check domain DNS configuration
3. Ensure nginx proxy is working

## Security Notes

- All clients share the same OAuth configuration but have isolated data
- Each client gets their own session storage and user database
- Data volumes are isolated between clients
- Consider firewall rules for production deployment

## Production Deployment

### Quick Start (Automated)

```bash
# 1. Deploy HOST nginx
./client-manager.sh
# Choose option 6: "Manage nginx Installation"
# Select 1: "Install nginx on HOST (Production - Recommended)"

# 2. Deploy and configure clients with automated HTTPS
./client-manager.sh
# Choose "3) Create New Deployment" and follow the prompts
# SSL certificates are generated automatically
```

### Detailed Steps

1. **Deploy nginx**: Use client-manager.sh option 6 for HOST nginx (recommended)
2. **Deploy Client Containers**: Use client-manager.sh for automated setup
3. **Configure HTTPS**: Automated through client-manager.sh (option 5)
4. **Update Google OAuth redirect URIs**: Add client domains to Google Cloud Console
5. **Configure firewall rules**: Allow ports 80, 443 for HTTPS (auto-configured by setup)
6. **Set up monitoring and backups**: See [tests/README.md](tests/README.md) for monitoring setup

**📖 For complete documentation on nginx modes**, see [nginx/DEV_PLAN_FOR_NGINX_GET_WELL.md](nginx/DEV_PLAN_FOR_NGINX_GET_WELL.md)

---

## System Requirements

> **Note**: This section is continuously updated based on production observations. Memory requirements may vary based on workload, number of concurrent users, and model configurations.

### Minimum Hardware Requirements

Based on observed metrics in production environments:

| Component | Minimum RAM | Notes |
|-----------|-------------|-------|
| **nginx Container** | 460 MB | With 2 client deployments configured |
| **Open WebUI Instance** | 600 MB per instance | Per client deployment |
| **Operating System** | 200-300 MB | Ubuntu baseline |
| **System Overhead** | 100-200 MB | Docker, system processes |

### Recommended Droplet Sizes

**For 1-2 Client Deployments:**
- **Droplet Size**: 2GB RAM / 1 vCPU / 50GB SSD
- **Monthly Cost**: $12
- **Memory Breakdown**:
  - nginx: 460 MB
  - 2 Open WebUI instances: 1,200 MB (600 MB × 2)
  - System overhead: ~340 MB
  - **Total**: ~2 GB

**For 3-4 Client Deployments:**
- **Droplet Size**: 4GB RAM / 2 vCPU / 80GB SSD
- **Monthly Cost**: $24
- **Memory Breakdown**:
  - nginx: 460 MB
  - 4 Open WebUI instances: 2,400 MB (600 MB × 4)
  - System overhead: ~400 MB
  - **Total**: ~3.3 GB

**For 5-8 Client Deployments:**
- **Droplet Size**: 8GB RAM / 4 vCPU / 160GB SSD
- **Monthly Cost**: $48
- **Memory Breakdown**:
  - nginx: 460 MB
  - 8 Open WebUI instances: 4,800 MB (600 MB × 8)
  - System overhead: ~500 MB
  - **Total**: ~5.8 GB

### Storage Requirements

- **Base Installation**: ~5 GB (Docker images, system packages)
- **Per Client Instance**: 1-5 GB (varies with conversation history, uploaded files)
- **SSL Certificates**: <100 MB
- **nginx Logs**: 100 MB - 1 GB (depending on traffic and log retention)
- **Backups**: Plan for 2x data size if storing backups locally

**Recommended Storage Allocation:**
- 1-2 clients: 50 GB SSD
- 3-4 clients: 80 GB SSD
- 5-8 clients: 160 GB SSD
- 9+ clients: 320 GB SSD or add block storage

### CPU Requirements

- **Minimum**: 1 vCPU (suitable for light usage, 1-2 clients)
- **Recommended**: 2 vCPUs (smooth performance, 3-4 clients)
- **High Performance**: 4+ vCPUs (8+ clients or high concurrent usage)

### Network Requirements

- **Bandwidth**: 1-5 TB/month depending on usage
- **IPv6**: **Required** if using Supabase sync functionality
- **Ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS)

### Additional Considerations

**Memory Scaling Factors:**
- Memory usage increases with:
  - Number of concurrent active users
  - Size of LLM models being served (if using local models)
  - Conversation history length
  - Number of uploaded documents
  - RAG (Retrieval-Augmented Generation) workloads

**Production Recommendations:**
- Add 20-30% memory headroom for peaks
- Enable Digital Ocean monitoring to track actual usage
- Set up alerts for memory > 80% utilization
- Consider vertical scaling (upgrade droplet) vs horizontal (multiple servers)

### Monitoring Current Usage

Check current memory usage on your droplet:

```bash
# View overall memory usage
free -h

# View memory usage per container
docker stats --no-stream

# View memory usage for specific container
docker stats openwebui-nginx --no-stream
docker stats openwebui-CLIENT-NAME --no-stream
```

**Monitor in client-manager:**
- Option 1: View Deployment Status (shows container resource usage)

> **Contributing**: If you observe different memory requirements in your environment, please report them so we can refine these recommendations.
