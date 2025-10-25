# nginx Integration Development Plan - "Get Well" Initiative

**Project**: cb025370-2809-4f9b-b3b7-566a35909df2
**Date**: 2025-10-25
**Branch**: main → release
**Purpose**: Integrate validated HOST nginx deployment from pre-nginx-container-test into main branch

---

## Executive Summary

### The Problem
Containerized nginx deployment (experimental feature in main branch) breaks critical functionality:
- `/api/v1/utils/code/format` endpoint fails (pipe saves don't work)
- Validated on server 159.65.34.41 (chat-bc.quantabase.io) on 2025-10-25

### The Solution
HOST nginx (non-containerized, systemd service) works correctly:
- All pipes save successfully
- OAuth redirect loops fixed with WEBUI_BASE_URL
- Firewall auto-configured with fallback logic
- Validated on server 159.65.34.41 with pre-nginx-container-test branch

### Integration Goal
Merge validated HOST nginx from pre-nginx-container-test → main, while:
- Preserving all existing main branch features (Security Advisor, containerized nginx)
- Marking containerized nginx as experimental
- Ensuring qbmgr user can perform all operations without permission errors
- Supporting staging AND production SSL certificates
- Creating 3 automated test plans for validation

---

## Critical Context for New Sessions

### Branch Architecture
- **pre-nginx-container-test**: Contains validated HOST nginx functions + WEBUI_BASE_URL fix (3013 lines)
- **main**: Contains Security Advisor + containerized nginx auto-detection (3337 lines)
- **Integration Target**: main branch
- **Final Deployment**: release branch (after all tests pass)

### Analysis Documents Location
**IMPORTANT**: The following analysis documents are in pre-nginx-container-test for CONTEXT ONLY:
- `mt/tests/BRANCH_COMPARISON_ANALYSIS.md` - Detailed branch comparison
- `mt/tests/QBMGR_PERMISSIONS_AUDIT.md` - Complete permissions audit

**These documents do NOT get merged into main**. They exist for reference during integration.

### What DOES Get Merged Into Main
1. **Functions from pre-nginx-container-test**:
   - `manage_nginx_menu()` - Submenu for nginx management
   - `install_nginx_host()` - Installs nginx via apt + configures firewall
   - `check_nginx_status()` - Checks both HOST and containerized modes
   - `uninstall_nginx()` - Removes nginx installations
   - Improved firewall logic with 'Nginx Full' profile + fallback

2. **WEBUI_BASE_URL Fix** (Critical for OAuth):
   - start-template.sh: Add BASE_URL calculation and -e WEBUI_BASE_URL
   - Fixes OAuth redirect loops on HTTPS domains

3. **Test Plans** (New files in mt/tests/):
   - NEW_SERVER_BUILD_TEST.md
   - NGINX_BUILD_TEST.md
   - CLIENT_DEPLOYMENT_TEST.md

### What Gets Preserved in Main
- Security Advisor system (5 check functions + menu option)
- Containerized nginx auto-detection in create_new_deployment()
- Dynamic menu text for nginx container status
- OAUTH_DOMAINS and WEBUI_SECRET_KEY parameters
- All existing menu structure and functionality

---

## Technical Background

### Root Cause: nginx Containerization Bug
From ROOT_CAUSE_NGINX_CONTAINERIZATION.md (commit d191e5345 baseline):
- Containerized nginx breaks pipe saves via `/api/v1/utils/code/format`
- HOST nginx with port mapping works correctly
- Server 159.65.34.41 validated working with HOST nginx
- VAULT rollback was unnecessary - nginx containerization was the real issue

### OAuth Redirect Loop Fix
**Problem**: After Google OAuth login, site flashes/loops on https://domain
**Root Cause**: Missing WEBUI_BASE_URL environment variable
- JavaScript can't determine correct API endpoint behind nginx + Cloudflare
- Happens BEFORE login attempt (pre-login JavaScript initialization issue)

**Solution**: Always set WEBUI_BASE_URL explicitly
```bash
if [[ "$DOMAIN" == localhost* ]]; then
    BASE_URL="http://${DOMAIN}"
else
    BASE_URL="https://${DOMAIN}"
fi
docker run ... -e WEBUI_BASE_URL=${BASE_URL}
```

### qbmgr User Permissions
**Setup** (from mt/setup/quick-setup.sh):
- Member of: sudo, docker groups
- Passwordless sudo: ENABLED (/etc/sudoers.d/qbmgr)
- Can run all operations without password prompts

**Critical Issue Found**: generate_nginx_config() shows manual instructions instead of automating
```bash
# Current (WRONG):
echo "   sudo cp $config_file /etc/nginx/sites-available/${domain}"

# Should be (CORRECT):
sudo cp "$config_file" "/etc/nginx/sites-available/${domain}"
sudo ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/${domain}"
sudo nginx -t
```

### Firewall Configuration with Fallback
**Challenge**: UFW 'Nginx Full' profile doesn't always exist on fresh Ubuntu installs

**Solution**: Try profile first, fallback to direct ports
```bash
if sudo ufw allow 'Nginx Full' 2>/dev/null; then
    # Verify rules added
    if sudo ufw status | grep -q "Nginx Full"; then
        echo "✅ Firewall configured (Nginx Full profile)"
    else
        # Profile didn't work, use fallback
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        echo "✅ Firewall configured (direct ports 80, 443)"
    fi
else
    # Fallback to direct ports
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    echo "✅ Firewall configured (direct ports 80, 443)"
fi
```

---

## Archon Task List (Priority Order)

### Phase 1: Research & Analysis ✅ COMPLETED
**Status**: 2/2 tasks completed

#### Task 1: Compare Branches (DONE)
- **ID**: d71ad561-db3d-4d14-81a3-1ef26e721c3b
- **Order**: 113 (highest)
- **Deliverable**: mt/tests/BRANCH_COMPARISON_ANALYSIS.md (in pre-nginx-container-test)
- **Key Findings**:
  - main: 3337 lines, has Security Advisor + containerized nginx
  - pre-nginx-container-test: 3013 lines, has HOST nginx + WEBUI_BASE_URL fix
  - Difference: -324 lines (simpler code in pre-nginx-container-test)

#### Task 2: Audit Permissions (DONE)
- **ID**: daa9c3c0-a5a5-4748-9f35-fb4aec90d3dd
- **Order**: 107
- **Deliverable**: mt/tests/QBMGR_PERMISSIONS_AUDIT.md (in pre-nginx-container-test)
- **Key Findings**:
  - qbmgr has passwordless sudo (correct setup)
  - CRITICAL: generate_nginx_config() needs automation (Priority 1 fix)
  - All systemctl, apt-get, ufw operations correctly use sudo

### Phase 2: Integration ✅ READY TO START
**Status**: 0/5 tasks completed
**Prerequisites**: Phase 1 completed

#### Task 3: Merge nginx Management Menu
- **ID**: acd11273-ab0d-40bc-ad6a-c6b23c9703cd
- **Order**: 101
- **File**: mt/client-manager.sh
- **Actions**:
  1. Copy 4 functions from pre-nginx-container-test to main:
     - `manage_nginx_menu()` (lines ~2330-2370 in pre-nginx-container-test)
     - `install_nginx_host()` (lines ~2380-2490)
     - `check_nginx_status()` (lines ~2340-2360)
     - `uninstall_nginx()` (lines ~2600-2630)
  2. Update check_nginx_status() to check BOTH HOST and containerized modes
  3. Ensure no conflicts with existing containerized nginx functions
- **Validation**: Functions added without breaking existing features

#### Task 4: Update Main Menu
- **ID**: d53fda86-d9c6-471d-93c4-9e6ed0376c82
- **Order**: 95
- **File**: mt/client-manager.sh
- **Actions**:
  1. Add option "6) Manage nginx Installation"
  2. Renumber existing option 6 (Exit) to option 8
  3. Keep option 7 as "Security Advisor" (from main)
  4. Update case statement to handle new option 6
- **Validation**: Menu displays correctly, all options work

#### Task 5: Automate Config File Operations (CRITICAL)
- **ID**: 7fb6348e-b676-4136-8395-2f9e991f9e0c
- **Order**: 89
- **File**: mt/client-manager.sh
- **Function**: generate_nginx_config()
- **Actions**:
  1. Replace instruction echoes with actual sudo operations
  2. Copy config: `sudo cp "$config_file" "/etc/nginx/sites-available/${domain}"`
  3. Enable site: `sudo ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/${domain}"`
  4. Test config: `sudo nginx -t`
  5. Offer reload: Prompt user, run `sudo systemctl reload nginx`
- **Why Critical**: qbmgr user needs automation, not manual copy-paste instructions
- **Validation**: Config installation is fully automated

#### Task 6: Update install_nginx_container()
- **ID**: 2009c21d-caa1-4f67-b935-658a8a4a3ac2
- **Order**: 77
- **File**: mt/client-manager.sh
- **Actions**:
  1. Replace placeholder with call to mt/nginx-container/deploy-nginx-container.sh
  2. Add user confirmation prompt
  3. Keep "⚠️ EXPERIMENTAL" warnings
  4. Handle script errors and report to user
- **Validation**: Containerized nginx deployment works via menu

#### Task 7: Merge WEBUI_BASE_URL Fix (CRITICAL for OAuth)
- **ID**: 68600deb-a68f-49b9-8e23-559db911a3ef
- **Order**: 71
- **Files**: mt/start-template.sh, mt/client-manager.sh
- **Actions**:
  1. **start-template.sh**:
     - Add BASE_URL calculation (lines ~24-31 in pre-nginx-container-test)
     - Add `-e WEBUI_BASE_URL=${BASE_URL}` to docker run command
  2. **client-manager.sh**:
     - Find all docker run commands
     - Ensure WEBUI_BASE_URL is set in each
- **Why Critical**: Fixes OAuth redirect loops on HTTPS domains
- **Validation**: OAuth login works on HTTPS without redirect loops

### Phase 3: SSL Enhancement
**Status**: 0/1 task completed
**Prerequisites**: Phase 2 tasks 3-5 completed

#### Task 8: Implement Staging vs Production Certificates
- **ID**: 05ac1c0c-5619-4aa0-b815-8d9997df4a93
- **Order**: 83
- **File**: mt/client-manager.sh
- **Function**: generate_nginx_config() (after config installation)
- **Actions**:
  1. Add certificate selection prompt:
     ```
     1) Production certificate (Let's Encrypt)
     2) Staging certificate (for testing)
     3) Skip (generate later)
     ```
  2. For option 1: `sudo certbot --nginx -d "${domain}" --non-interactive --agree-tos --email admin@${domain}`
  3. For option 2: Add `--staging` flag
  4. For option 3: Show manual commands
  5. Document Let's Encrypt rate limits (5 certs per domain per week)
- **Validation**: Both staging and production certs can be generated

### Phase 4: Testing Documentation
**Status**: 0/3 tasks completed
**Prerequisites**: Phase 2 and 3 completed (all integration work done)

#### Task 9: Create NEW_SERVER_BUILD_TEST.md
- **ID**: c2d8f64e-0587-487d-8ea8-0fb07f5c1386
- **Order**: 65
- **File**: mt/tests/NEW_SERVER_BUILD_TEST.md (NEW FILE)
- **Purpose**: Test complete server setup from scratch
- **Sections**:
  1. Prerequisites (Digital Ocean account, SSH key)
  2. Create DO droplet (Ubuntu 24.04)
  3. Run quick-setup.sh
  4. SSH as qbmgr user
  5. Verify tools installed (docker, git, nginx availability)
  6. Launch client-manager.sh
  7. Verify permissions (sudo works without password)
  8. Pass/fail criteria with expected outputs
- **Validation**: Document can be followed by new user

#### Task 10: Create NGINX_BUILD_TEST.md
- **ID**: ae139a9b-8094-4e1d-8090-f4ea04b5ecaa
- **Order**: 59
- **File**: mt/tests/NGINX_BUILD_TEST.md (NEW FILE)
- **Purpose**: Test both nginx deployment modes
- **Sections**:
  1. HOST nginx Installation
     - Install via client-manager menu
     - Verify nginx service running
     - Validate firewall rules (80, 443)
     - Check certbot installed
  2. Containerized nginx Deployment (Experimental)
     - Deploy via client-manager menu
     - Verify container running
     - Check network configuration
  3. Config Generation
     - Generate nginx config for test domain
     - Verify auto-installation works
     - Test nginx -t passes
  4. SSL Certificate Creation
     - Test staging certificate generation
     - Verify HTTPS access
  5. nginx Reload/Status Operations
- **Validation**: Both deployment modes tested

#### Task 11: Create CLIENT_DEPLOYMENT_TEST.md
- **ID**: 55bf06b7-01bc-446c-ba7c-403d8b81d4ac
- **Order**: 53
- **File**: mt/tests/CLIENT_DEPLOYMENT_TEST.md (NEW FILE)
- **Purpose**: Test complete client deployment workflow
- **Test Domain**: chat-test-01.quantabase.io
- **Sections**:
  1. Create deployment via client-manager option 2
  2. Generate nginx config (verify auto-installation)
  3. Test nginx configuration (nginx -t)
  4. Generate staging SSL certificate
  5. Verify HTTPS access (https://chat-test-01.quantabase.io)
  6. Test Google OAuth login (no redirect loops)
  7. Test function pipes (critical validation)
  8. Verify WEBUI_BASE_URL set correctly
- **Validation**: End-to-end deployment works with all features

### Phase 5: Validation & Documentation
**Status**: 0/2 tasks completed
**Prerequisites**: Phase 4 completed (all test plans created)

#### Task 12: Test Complete Workflow on Fresh Server
- **ID**: 9b568f07-bb47-4188-8be2-0655c6ded9b6
- **Order**: 47
- **Purpose**: Validate all 3 test plans pass
- **Actions**:
  1. Deploy fresh Digital Ocean droplet
  2. Run quick-setup.sh
  3. Execute NEW_SERVER_BUILD_TEST.md (document results)
  4. Execute NGINX_BUILD_TEST.md (document results)
  5. Execute CLIENT_DEPLOYMENT_TEST.md (document results)
  6. If ANY test fails: Fix issues, repeat from step 1
  7. Continue until ALL tests pass
- **Success Criteria**: All 3 test plans pass on fresh server
- **Validation**: Document test run in git commit message

#### Task 13: Update mt/setup/README.md
- **ID**: 9be3eac2-a475-4947-85d1-bfd747c1c078
- **Order**: 41
- **File**: mt/setup/README.md
- **Actions**:
  1. Add section "nginx Deployment Modes"
  2. Document HOST nginx (recommended, production-ready)
  3. Document containerized nginx (experimental, known issues)
  4. Add "Choosing Between Modes" guide
  5. Document staging vs production certificates
  6. Add troubleshooting section
- **Validation**: README clearly explains both deployment options

### Phase 6: Deployment
**Status**: 0/1 task completed
**Prerequisites**: Phase 5 completed (all tests pass)

#### Task 14: Create Merge Request to Release Branch
- **ID**: f0405976-4d8c-4d80-92ea-26da2d3beb0f
- **Order**: 35 (final task)
- **Actions**:
  1. Ensure all commits are in main branch
  2. Create PR/MR: main → release
  3. Include in PR description:
     - Summary of changes (HOST nginx integration)
     - Test results (all 3 test plans passed)
     - Validation on server 159.65.34.41
     - Breaking changes (none expected)
     - Migration notes for existing deployments
  4. Tag for review
  5. After approval: Merge to release branch
- **Success Criteria**: Changes deployed to production-ready release branch

---

## Implementation Checklist

Use this checklist to track progress:

### Phase 1: Research ✅
- [x] Compare branches (d71ad561)
- [x] Audit permissions (daa9c3c0)

### Phase 2: Integration
- [ ] Merge nginx menu functions (acd11273)
- [ ] Update main menu structure (d53fda86)
- [ ] Automate config file operations (7fb6348e)
- [ ] Update install_nginx_container() (2009c21d)
- [ ] Merge WEBUI_BASE_URL fix (68600deb)

### Phase 3: SSL
- [ ] Implement staging vs production certs (05ac1c0c)

### Phase 4: Testing
- [ ] Create NEW_SERVER_BUILD_TEST.md (c2d8f64e)
- [ ] Create NGINX_BUILD_TEST.md (ae139a9b)
- [ ] Create CLIENT_DEPLOYMENT_TEST.md (55bf06b7)

### Phase 5: Validation
- [ ] Test complete workflow (9b568f07)
- [ ] Update README documentation (9be3eac2)

### Phase 6: Deployment
- [ ] Create merge request to release (f0405976)

---

## File Modification Summary

### Files to Modify in Main Branch

**mt/client-manager.sh** (primary integration file):
- Add 4 functions from pre-nginx-container-test
- Update main menu (add option 6, renumber 6→8)
- Automate generate_nginx_config() operations
- Update install_nginx_container() to call deploy script
- Add WEBUI_BASE_URL to container creation points
- Add staging vs production certificate selection

**mt/start-template.sh**:
- Add BASE_URL calculation
- Add -e WEBUI_BASE_URL to docker run

**mt/setup/README.md**:
- Add dual nginx mode documentation
- Document certificate options

### Files to Create in Main Branch

**mt/tests/NEW_SERVER_BUILD_TEST.md** (new)
**mt/tests/NGINX_BUILD_TEST.md** (new)
**mt/tests/CLIENT_DEPLOYMENT_TEST.md** (new)

### Files NOT Modified (Reference Only)
**In pre-nginx-container-test** (for context):
- mt/tests/BRANCH_COMPARISON_ANALYSIS.md
- mt/tests/QBMGR_PERMISSIONS_AUDIT.md

---

## Key Code Snippets for Integration

### 1. BASE_URL Calculation (start-template.sh)
```bash
# Set redirect URI and environment based on domain type
if [[ "$DOMAIN" == localhost* ]] || [[ "$DOMAIN" == 127.0.0.1* ]]; then
    REDIRECT_URI="http://${DOMAIN}/oauth/google/callback"
    BASE_URL="http://${DOMAIN}"
    ENVIRONMENT="development"
else
    REDIRECT_URI="https://${DOMAIN}/oauth/google/callback"
    BASE_URL="https://${DOMAIN}"
    ENVIRONMENT="production"
fi
```

### 2. Add WEBUI_BASE_URL to Docker Run
```bash
docker run -d \
    --name ${CONTAINER_NAME} \
    ${PORT_CONFIG} \
    ${NETWORK_CONFIG} \
    -e WEBUI_BASE_URL=${BASE_URL} \
    # ... other environment variables
```

### 3. Automated Config Installation (generate_nginx_config)
```bash
echo "📋 Installing nginx configuration..."

# Copy config to sites-available
if sudo cp "$config_file" "/etc/nginx/sites-available/${domain}"; then
    echo "✅ Config copied to /etc/nginx/sites-available/${domain}"
else
    echo "❌ Failed to copy config"
    return 1
fi

# Enable site
if sudo ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/${domain}"; then
    echo "✅ Site enabled"
else
    echo "❌ Failed to enable site"
    return 1
fi

# Test nginx config
echo "🔍 Testing nginx configuration..."
if sudo nginx -t; then
    echo "✅ nginx configuration test passed"
else
    echo "❌ nginx configuration has errors"
    return 1
fi

# Offer to reload
echo -n "Reload nginx now? (y/N): "
read reload_confirm
if [[ "$reload_confirm" =~ ^[Yy]$ ]]; then
    if sudo systemctl reload nginx; then
        echo "✅ nginx reloaded successfully"
    else
        echo "❌ Failed to reload nginx"
        return 1
    fi
fi
```

### 4. Firewall Configuration with Fallback (install_nginx_host)
```bash
echo "🔥 Configuring firewall..."

if sudo ufw allow 'Nginx Full' 2>/dev/null; then
    # Verify it actually worked
    if sudo ufw status | grep -q "Nginx Full"; then
        echo "✅ Firewall configured (Nginx Full profile)"
    else
        # Profile didn't work, use fallback
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        echo "✅ Firewall configured (direct ports 80, 443)"
    fi
else
    # Fallback to direct ports
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    echo "✅ Firewall configured (direct ports 80, 443)"
fi
```

### 5. Certificate Selection Menu
```bash
echo "═══════════════════════════════════════"
echo "SSL Certificate Setup"
echo "═══════════════════════════════════════"
echo
echo "Do you want to generate an SSL certificate now?"
echo "1) Production certificate (Let's Encrypt)"
echo "2) Staging certificate (for testing)"
echo "3) Skip (generate later)"
echo
echo -n "Choose option (1-3): "
read cert_choice

case "$cert_choice" in
    1)
        echo "Generating production SSL certificate..."
        sudo certbot --nginx -d "${domain}" --non-interactive --agree-tos --email admin@${domain}
        ;;
    2)
        echo "Generating staging SSL certificate..."
        sudo certbot --nginx -d "${domain}" --staging --non-interactive --agree-tos --email admin@${domain}
        ;;
    3)
        echo "Skipped. Generate later with:"
        echo "  Production: sudo certbot --nginx -d ${domain}"
        echo "  Staging: sudo certbot --nginx -d ${domain} --staging"
        ;;
esac
```

---

## Risk Assessment

### Low Risk Changes
- WEBUI_BASE_URL addition (isolated, well-tested)
- Firewall fallback logic (safe, improves reliability)
- Certificate selection menu (optional feature)

### Medium Risk Changes
- nginx menu integration (well-defined functions, tested in pre-nginx-container-test)
- Config file automation (replaces manual steps, improves UX)

### High Risk Changes
- Menu structure changes (affects user experience, must preserve existing options)
- start-template.sh modifications (used everywhere, must test thoroughly)

### Mitigation Strategy
1. Test each phase independently
2. Run all 3 test plans on fresh server before merging to release
3. Keep containerized nginx as fallback option
4. Document rollback procedure in commit messages

---

## Success Criteria

### Technical Validation
- [ ] All 14 Archon tasks marked "done"
- [ ] All 3 test plans pass on fresh server
- [ ] No regressions in existing functionality
- [ ] qbmgr can perform all operations without permission errors
- [ ] OAuth redirect loops resolved
- [ ] Function pipes work correctly
- [ ] Both staging and production certificates can be generated

### Code Quality
- [ ] No merge conflicts
- [ ] All functions documented
- [ ] Error handling implemented
- [ ] User feedback messages clear and helpful

### Documentation
- [ ] README updated with dual nginx mode information
- [ ] Test plans provide clear pass/fail criteria
- [ ] Commit messages reference Archon task IDs

### Deployment Readiness
- [ ] Changes merged to main branch
- [ ] All tests pass
- [ ] PR created to release branch
- [ ] Review completed and approved

---

## Notes for New Claude Sessions

1. **Start Here**: Read this document first to understand context and objectives

2. **Check Archon Tasks**: Use `find_tasks(filter_by="project", filter_value="cb025370-2809-4f9b-b3b7-566a35909df2")` to see current status

3. **Reference Documents**: Analysis docs are in pre-nginx-container-test branch for context:
   - `git checkout pre-nginx-container-test`
   - Read `mt/tests/BRANCH_COMPARISON_ANALYSIS.md`
   - Read `mt/tests/QBMGR_PERMISSIONS_AUDIT.md`
   - `git checkout main` (return to working branch)

4. **Update Task Status**: Always update Archon tasks:
   - Before starting: `manage_task("update", task_id="...", status="doing")`
   - After completing: `manage_task("update", task_id="...", status="review")`

5. **Follow Phases**: Complete phases in order (2 → 3 → 4 → 5 → 6)

6. **Test Thoroughly**: Each phase should be tested before moving to next phase

7. **Document Changes**: Reference Archon task IDs in commit messages

8. **Ask User for Validation**: After completing each phase, confirm with user before proceeding

---

## Quick Start Guide

**To continue this work:**

1. Verify current status:
   ```bash
   # Check Archon tasks
   find_tasks(filter_by="project", filter_value="cb025370-2809-4f9b-b3b7-566a35909df2")
   ```

2. Start Phase 2 (Integration):
   ```bash
   # Begin with Task 3: Merge nginx menu
   manage_task("update", task_id="acd11273-ab0d-40bc-ad6a-c6b23c9703cd", status="doing")

   # Read pre-nginx-container-test version
   git show pre-nginx-container-test:mt/client-manager.sh | grep -A 50 "manage_nginx_menu()"
   ```

3. Follow implementation checklist above

4. Update task status as you complete each one

5. After Phase 2, 3, 4: Run tests before proceeding to next phase

6. After Phase 5: Coordinate with user for release merge

---

**END OF DEVELOPMENT PLAN**
