# Quick Start Guide - Production Server Migration

## For Server: 45.55.182.177 (chat.lawnloonies.com)

### Step-by-Step Commands

```bash
# 1. Connect to server
ssh qbmgr@45.55.182.177
cd ~/open-webui/mt/migration

# 2. Discover current state (optional but recommended)
bash 1-discover-deployments.sh

# 3. Backup deployment
bash 2-backup-deployment.sh openwebui-chat-lawnloonies-com

# 4. Prepare environment (one-time)
bash 3-prepare-environment.sh

# 5. Migrate deployment (~2 minutes downtime)
bash 4-migrate-deployment.sh \
    openwebui-chat-lawnloonies-com \
    chat.lawnloonies.com \
    chat

# 6. Verify migration
bash 5-verify-migration.sh \
    openwebui-chat-lawnloonies-com \
    chat.lawnloonies.com

# 7. MANUAL TESTING REQUIRED!
# - Open: https://chat.lawnloonies.com
# - Login with existing account
# - Verify chat history intact
# - Send test message
# - Check branding

# 8. After successful verification, cleanup old volume
bash 6-cleanup-old-volume.sh openwebui-chat-lawnloonies-com
```

### If Something Goes Wrong

```bash
# Rollback to old architecture
bash 9-rollback-deployment.sh openwebui-chat-lawnloonies-com
```

### Expected Timeline

- Backup: ~3 minutes
- Preparation: ~7 minutes (one-time)
- Migration: ~4 minutes (2 min downtime)
- Verification: ~10 minutes
- **Total: ~25 minutes**

### What Changes

**Before:**
- Storage: Docker volume at `/var/lib/docker/volumes/openwebui-chat-lawnloonies-com-data/_data/`
- Image: `ghcr.io/imagicrafter/open-webui:release`
- Branch: `release`

**After:**
- Storage: Bind mounts at `/opt/openwebui/chat-lawnloonies-com/`
- Image: `ghcr.io/imagicrafter/open-webui:main`
- Branch: `main`

### Key Safety Features

- ✅ Backup created before any changes
- ✅ Old volume kept until cleanup confirmed
- ✅ Database verified after migration
- ✅ Rollback available at any time
- ✅ No data loss risk

### Need Help?

See detailed troubleshooting in `README.md` or full plan in `../MIGRATION_PLAN.md`

