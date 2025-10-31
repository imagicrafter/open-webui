# Phase 1 - Critical Bug Fix: CLIENT_ID Architecture

**Date:** 2025-10-31
**Status:** ✅ FIXED (commit 1deaa9196)
**Severity:** CRITICAL - Data corruption risk

---

## Problem Discovered

During Phase 1 validation testing on server 167.71.94.196, discovered that **multiple deployments with the same subdomain were sharing the same data directory**.

### Observed Behavior:
```bash
# Both containers mounted to SAME directory:
openwebui-chat-imagicrafter-ai  → /opt/openwebui/chat/
openwebui-chat-lawnloonies-com  → /opt/openwebui/chat/

# Both containers writing to SAME SQLite database:
/opt/openwebui/chat/data/webui.db
```

**Data Corruption Risk:** Multiple containers modifying the same SQLite database simultaneously = HIGH risk of corruption.

---

## Root Cause Analysis

### Original (BROKEN) Architecture:

**start-template.sh line 24:**
```bash
CLIENT_DIR="/opt/openwebui/${CLIENT_NAME}"
```

**Problem:** `CLIENT_NAME` was the subdomain only (e.g., "chat"), not a unique identifier.

**client-manager.sh flow:**
1. User enters: `client_name: "chat"`
2. User enters: `fqdn: "chat.imagicrafter.ai"`
3. Script generates: `container_name: "openwebui-chat-imagicrafter-ai"` ✅ (unique!)
4. Script passes to start-template.sh: `CLIENT_NAME="chat"` ❌ (NOT unique!)
5. start-template.sh creates: `CLIENT_DIR="/opt/openwebui/chat/"` ❌ (collision!)

**Result:** All deployments with subdomain "chat" share the same directory:
- chat.imagicrafter.ai → /opt/openwebui/chat/
- chat.lawnloonies.com → /opt/openwebui/chat/
- chat.acme-corp.com → /opt/openwebui/chat/

---

## Solution Implemented

### New (FIXED) Architecture:

**start-template.sh lines 23-28:**
```bash
# Extract CLIENT_ID from CONTAINER_NAME (strip "openwebui-" prefix)
# This is the unique identifier for this deployment (sanitized FQDN)
CLIENT_ID="${CONTAINER_NAME#openwebui-}"

# Per-client directory for volume mounts (uses CLIENT_ID for uniqueness)
CLIENT_DIR="/opt/openwebui/${CLIENT_ID}"
```

**Variable Naming Improvements:**
- `CLIENT_NAME` → `SUBDOMAIN` (clarifies it's just the subdomain)
- `sanitized_fqdn` → `CLIENT_ID` (clarifies it's the unique identifier)
- `CLIENT_DIR` now uses `CLIENT_ID` for uniqueness

**Result:** Each deployment gets isolated directory based on full FQDN:
- chat.imagicrafter.ai → /opt/openwebui/chat-imagicrafter-ai/ ✅
- chat.lawnloonies.com → /opt/openwebui/chat-lawnloonies-com/ ✅
- chat.acme-corp.com → /opt/openwebui/chat-acme-corp-com/ ✅

**Environment Variables Updated:**
```bash
-e CLIENT_ID="${CLIENT_ID}"          # e.g., "chat-imagicrafter-ai"
-e SUBDOMAIN="${SUBDOMAIN}"          # e.g., "chat"
-e FQDN="${FQDN}"                    # e.g., "chat.imagicrafter.ai"
```

---

## Migration Required

### Existing Deployments on 167.71.94.196:

**Current State (BROKEN):**
```
/opt/openwebui/chat/data/      ← Shared by both!
/opt/openwebui/chat/static/    ← Shared by both!

openwebui-chat-imagicrafter-ai → /opt/openwebui/chat/
openwebui-chat-lawnloonies-com → /opt/openwebui/chat/
```

**Target State (FIXED):**
```
/opt/openwebui/chat-imagicrafter-ai/data/
/opt/openwebui/chat-imagicrafter-ai/static/

/opt/openwebui/chat-lawnloonies-com/data/
/opt/openwebui/chat-lawnloonies-com/static/
```

### Migration Steps:

Since these are test deployments <1 hour old with no production data:

```bash
ssh root@167.71.94.196

# 1. Stop both containers
docker stop openwebui-chat-imagicrafter-ai openwebui-chat-lawnloonies-com

# 2. Remove containers
docker rm openwebui-chat-imagicrafter-ai openwebui-chat-lawnloonies-com

# 3. Remove shared directory (no important data)
rm -rf /opt/openwebui/chat/

# 4. Update repository to latest fix
sudo -u qbmgr bash -c 'cd ~/open-webui && git fetch && git pull'

# 5. Recreate deployments (they'll use new CLIENT_ID logic)
sudo -u qbmgr bash

# From qbmgr shell, run client-manager:
cd ~/open-webui/mt
./client-manager.sh
# Select: 2) Create New Deployment
# Enter client name: chat
# Enter FQDN: chat.imagicrafter.ai

# Repeat for second deployment:
# Enter client name: chat
# Enter FQDN: chat.lawnloonies.com

# 6. Verify isolation
docker inspect openwebui-chat-imagicrafter-ai --format '{{range .Mounts}}{{.Source}}{{println}}{{end}}'
# Expected: /opt/openwebui/chat-imagicrafter-ai/data
#           /opt/openwebui/chat-imagicrafter-ai/static

docker inspect openwebui-chat-lawnloonies-com --format '{{range .Mounts}}{{.Source}}{{println}}{{end}}'
# Expected: /opt/openwebui/chat-lawnloonies-com/data
#           /opt/openwebui/chat-lawnloonies-com/static
```

### For Production Deployments with Data:

If deployments have important data that needs to be preserved:

```bash
# 1. Determine which deployment should keep the data
# (Assuming chat.imagicrafter.ai keeps the data)

# 2. Stop containers
docker stop openwebui-chat-imagicrafter-ai openwebui-chat-lawnloonies-com

# 3. Create new directories
mkdir -p /opt/openwebui/chat-imagicrafter-ai
mkdir -p /opt/openwebui/chat-lawnloonies-com

# 4. Move data to first deployment
mv /opt/openwebui/chat/data /opt/openwebui/chat-imagicrafter-ai/
mv /opt/openwebui/chat/static /opt/openwebui/chat-imagicrafter-ai/

# 5. Initialize empty directories for second deployment
mkdir -p /opt/openwebui/chat-lawnloonies-com/data
mkdir -p /opt/openwebui/chat-lawnloonies-com/static
cp -a /opt/openwebui/defaults/static/. /opt/openwebui/chat-lawnloonies-com/static/

# 6. Set ownership
chown -R qbmgr:qbmgr /opt/openwebui/chat-imagicrafter-ai
chown -R qbmgr:qbmgr /opt/openwebui/chat-lawnloonies-com

# 7. Remove old shared directory
rm -rf /opt/openwebui/chat/

# 8. Update mounts in containers (recreate with new paths)
docker rm openwebui-chat-imagicrafter-ai openwebui-chat-lawnloonies-com
# Then recreate via client-manager
```

---

## Validation Checklist

After migration, verify isolation:

- [ ] Each container has unique CLIENT_DIR
- [ ] No /opt/openwebui/chat/ directory exists
- [ ] Mount sources use full CLIENT_ID:
  ```bash
  docker inspect openwebui-chat-imagicrafter-ai --format '{{range .Mounts}}{{.Source}}{{println}}{{end}}'
  # Must show: /opt/openwebui/chat-imagicrafter-ai/...
  ```
- [ ] Each deployment can be managed independently
- [ ] Data changes in one deployment don't affect the other
- [ ] Static assets can be customized per deployment

---

## Impact on Phase 1

**Status Before Fix:** ❌ FAILED - Data isolation broken
**Status After Fix:** ✅ READY for validation

**Changes Required:**
- ✅ start-template.sh updated (commit 1deaa9196)
- ✅ Variable naming improved (CLIENT_NAME → SUBDOMAIN, added CLIENT_ID)
- ⏳ Existing deployments need migration
- ⏳ Documentation needs update
- ⏳ Full end-to-end validation needed

---

## Lessons Learned

### Why This Wasn't Caught Earlier:

1. **Assumption Error:** Assumed `CLIENT_NAME` meant "unique client identifier" when it actually meant "subdomain"
2. **Testing Gap:** Never tested multiple deployments with the same subdomain
3. **Variable Naming:** "CLIENT_NAME" was ambiguous - didn't clearly indicate it was just subdomain
4. **Documentation Gap:** No clear explanation of multi-tenant naming conventions

### Prevention for Future:

1. ✅ Use descriptive variable names (`SUBDOMAIN`, `CLIENT_ID`, `FQDN`)
2. ✅ Test with realistic multi-tenant scenarios (same subdomain, different domains)
3. ✅ Always verify data isolation in validation checklist
4. ✅ Document exactly what each variable represents
5. ✅ Add validation checks to scripts to detect directory collisions

---

## Next Steps

1. ⏳ Migrate deployments on 167.71.94.196
2. ⏳ Run full validation with new CLIENT_ID architecture
3. ⏳ Update PHASE1_VALIDATION_ISSUES.md
4. ⏳ Update PHASE1_COMPLETION_REPORT.md
5. ⏳ Verify bind mounts work correctly with CLIENT_ID
6. ⏳ Test branding customization per CLIENT_ID

---

**Last Updated:** 2025-10-31
**Fix Commit:** 1deaa9196
**Next Action:** Migrate existing deployments and re-validate
