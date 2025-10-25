# ROOT CAUSE: nginx Containerization Breaks Pipe Saves

**Date:** 2025-10-24
**Status:** IDENTIFIED - Testing Required

## Critical Discovery

The function pipe save failure is **NOT** caused by Docker image pinning.

**The real issue:** nginx running in a Docker container vs. nginx running on the host.

## Evidence

### Working Server (45.55.59.141)

**nginx Configuration:**
```bash
$ systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
  Active: active (running) since Fri 2025-10-17 15:39:32 UTC
```
- nginx runs as **systemd service on HOST**
- nginx config at `/etc/nginx/sites-available/`

**Open WebUI Configuration:**
```bash
$ docker ps
openwebui-chat-bc-quantabase-io  ghcr.io/imagicrafter/open-webui:main
```
- Container uses **PORT MAPPING**: `-p 8081:8080`
- nginx proxies to `localhost:8081`

**Result:** ✅ Function pipes save successfully

### Broken Deployments

**nginx Configuration:**
- nginx runs as **Docker container**
- Container name: `openwebui-nginx`
- On custom bridge network: `openwebui-network`

**Open WebUI Configuration:**
- Container on **BRIDGE NETWORK**: `--network openwebui-network`
- **NO PORT MAPPING** (container-to-container communication)
- nginx proxies to `http://container-name:8080`

**Result:** ❌ Function pipes fail to save with "Invalid HTTP request received"

## Timeline

### What Actually Happened

1. **Oct 17 09:20** (commit d191e5345)
   - Code supports HOST nginx with port mapping
   - This is what 45.55.59.141 used

2. **Oct 17 12:34** (commit 059436dff)
   - Added containerized nginx support
   - Auto-detection of nginx container mode

3. **Oct 17 15:50 UTC**
   - Server 45.55.59.141 created
   - Used HOST nginx (pre-containerization deployment method)
   - Works perfectly

4. **Oct 22** (commit 351ebba70)
   - VAULT integration added
   - Working server pulled this code
   - Still works (proves VAULT not the problem)

5. **Oct 23** (commits db9e84799, 68968fe72, caffec801)
   - Pipe save errors discovered on NEW deployments
   - Wrong diagnoses: WEBUI_SECRET_KEY, VAULT, Docker image
   - Real difference: NEW deployments used containerized nginx

## Previous Incorrect Analysis

We previously concluded:
- ❌ Docker image pinning was the problem
- ❌ VAULT integration caused the issue
- ❌ WEBUI_SECRET_KEY generation broke things

**Reality:**
- ✅ Containerized nginx breaks `/api/v1/utils/code/format` endpoint
- ✅ HOST nginx with port mapping works fine
- ✅ Docker image version doesn't matter
- ✅ VAULT integration works fine (working server has it)

## Branch Created

**Branch:** `pre-nginx-container-test`
**Base Commit:** d191e5345 (Oct 17 09:20)
**Purpose:** Test deployment with HOST nginx before containerization

This branch represents the code state just before containerized nginx support was added.

### Branch Details:
```bash
Branch: pre-nginx-container-test
Commit: d191e5345
Date: 2025-10-17 09:20:21 -0500
Message: feat: Enhance client registration and management scripts to support FQDN and port extraction
Docker Image: ghcr.io/imagicrafter/open-webui:main
```

## Next Steps

### Phase 1: Verify HOST nginx Works
1. Deploy new server using `pre-nginx-container-test` branch
2. Follow same process as 45.55.59.141 (HOST nginx)
3. Verify function pipes save successfully
4. Confirm this reproduces working behavior

### Phase 2: Test Containerized nginx
1. On same server, deploy nginx container
2. Redeploy Open WebUI client with containerized nginx
3. Test if pipe save breaks
4. Confirm containerization is the breaking change

### Phase 3: Fix Containerized nginx
If containerization confirmed as root cause:
- Investigate nginx proxy configuration differences
- Check HTTP headers passed to Open WebUI
- Test different nginx buffer/proxy settings
- Fix `/api/v1/utils/code/format` endpoint handling

## nginx Proxy Differences

### HOST nginx Proxy
```nginx
# Direct proxy to localhost port
location / {
    proxy_pass http://localhost:8081;
    # Standard proxy headers
}
```

### Containerized nginx Proxy
```nginx
# Proxy to container name via Docker network
location / {
    proxy_pass http://container-name:8080;
    # Same headers but different network path
}
```

Hypothesis: Container-to-container networking may handle HTTP/2, WebSockets, or request buffering differently than localhost proxying.

## Resolution Criteria

Issue will be considered resolved when:
1. Containerized nginx deployments can save function pipes
2. No "Invalid HTTP request received" errors
3. `/api/v1/utils/code/format` works through nginx container
4. Behavior matches HOST nginx deployments

## Impact Reassessment

**Severity:** HIGH (blocks nginx containerization feature)

**Affected:**
- All deployments using containerized nginx
- New deployments defaulting to container mode

**Not Affected:**
- Deployments using HOST nginx (like 45.55.59.141)
- Direct Open WebUI access without nginx

**Workaround:**
Use HOST nginx instead of containerized nginx until fix is implemented.
