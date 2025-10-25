# Issue: Function Pipe Save Failure with Containerized nginx

## Status: ROOT CAUSE IDENTIFIED

**Last Updated:** 2025-10-24 19:30 CDT

## ROOT CAUSE ANALYSIS

### Key Finding: Docker Image Difference

**Working Server (45.55.59.141 - Built Oct 17, 2025)**:
```bash
Docker Image: ghcr.io/imagicrafter/open-webui:main (unpinned :main tag)
Code Base: Commit b5c267446 or nearby (Oct 17-18)
Status: Function pipes SAVE SUCCESSFULLY
```

**Current Main Branch (Broken)**:
```bash
Docker Image: ghcr.io/imagicrafter/open-webui@sha256:bdf98b7bf21c... (pinned Sept 28)
Code Base: Current HEAD with pinned image
Status: Function pipes FAIL TO SAVE
```

### Timeline of Events

1. **Oct 17-18**: Working deployment created
   - Used `:main` Docker tag (unpinned)
   - Containerized nginx working
   - Function pipes save successfully

2. **Oct 22** (commit 351ebba70): VAULT integration added
   - Added env management system
   - Modified start-template.sh and client-manager.sh

3. **Oct 23**: Pipe save errors discovered on NEW deployments
   - Error: "Invalid HTTP request received"
   - JSON parsing failures in browser

4. **Oct 23** (commit db9e84799): First fix attempt
   - Disabled WEBUI_SECRET_KEY generation
   - Did not resolve issue

5. **Oct 23** (commit 68968fe72): VAULT rollback
   - Complete rollback of VAULT integration
   - Reverted to pre-VAULT code state
   - Issue persisted

6. **Oct 23** (commit caffec801): Docker image pinning
   - Pinned to Sept 28 version (sha256:bdf98b7bf21c...)
   - Commit message claimed this was "ACTUAL root cause"
   - **BUT**: Working server uses UNPINNED :main tag

### The Paradox

The Oct 23 fix attempts assumed:
- Unpinned `:main` tag was the problem
- Pinning to Sept 28 was the solution

**Reality** (comparing to working 45.55.59.141):
- Working server uses UNPINNED `:main` tag
- Pinned image is the DIFFERENCE, not the solution

### Proposed Solution

Revert Docker image back to unpinned `:main` tag to match working server configuration:

```bash
# Change from:
ghcr.io/imagicrafter/open-webui@sha256:bdf98b7bf21c32db09522d90f80715af668b2bd8c58cf9d02777940773ab7b27

# Back to:
ghcr.io/imagicrafter/open-webui:main
```

This matches the ONLY code difference between working Oct 17 deployment and current main branch.

## Problem Summary

When attempting to save a function pipe in Open WebUI through containerized nginx proxy, the save operation fails with JSON parsing errors. This issue now affects ALL deployments using containerized nginx, including newly created clients on previously working servers.

## Error Symptoms

### Browser Error
```
SyntaxError: Unexpected token 'I', "Invalid HT"... is not valid JSON
```

Toast error also shows:
```
[object Object]
```

### Backend Error (from uvicorn logs)
```
Invalid HTTP request received.
```

### HTTP Responses
- **Initial**: HTTP 400 Bad Request
- **After container restart**: HTTP 422 Unprocessable Entity
- **Endpoint**: `POST /api/v1/utils/code/format`

### Network Tab Details
- Request fails when clicking "Save" on function pipe
- Double-clicking format request shows "404: Not Found" (in some cases)
- Backend returns plain text error instead of expected JSON response
- Frontend expects JSON, receives plain text, causes parse error

## Affected Systems

### Confirmed Failing
- **chat.blanecanada.ai** (104.236.102.26) - Using containerized nginx
- **New clients** on previously working servers - Using containerized nginx
- Pattern: ALL deployments using nginx in Docker container

### Confirmed Working
- **chat-test-01.quantabase.io** - Pipe saves successfully
- **Direct container access** - Container-to-container communication works (returns expected 401 unauthorized)

## Investigation Steps Completed

### 1. Browser Cache (RULED OUT)
- L Tested in incognito mode - still fails
- L Hard refresh - no change
- **Conclusion**: Not a browser caching issue

### 2. Docker Image Verification (RULED OUT)
-  Both servers using identical pinned image: `sha256:bdf98b7bf21c...`
-  Image verified not corrupted
- **Conclusion**: Not an image issue

### 3. Python Version Check (RULED OUT)
-  Both servers: Python 3.11.13
-  No version mismatch
- **Conclusion**: Not a Python version issue

### 4. Environment Variables (RULED OUT)
-  Compared environment variables between working and failing servers
-  All identical
- **Conclusion**: Not an environment configuration issue

### 5. nginx Configuration (RULED OUT)
-  Compared nginx configs between servers
-  Configurations identical
-  nginx version: 1.29.2 on both
- **Conclusion**: Not a static nginx config issue

### 6. Container Restarts
- � Restarted Open WebUI container
  - Error changed from HTTP 400 to HTTP 422
  - Issue persists
- � Restarted nginx container
  - No change in behavior
- **Conclusion**: Restart changes error but doesn't fix issue

### 7. Direct Container Communication (PASSED)
-  curl from nginx container to Open WebUI container: Works
-  Returns expected 401 unauthorized (correct for unauthenticated request)
- **Conclusion**: Open WebUI backend is functioning, containers can communicate

### 8. Working Server Comparison
-  chat-test-01.quantabase.io saves pipes successfully
-  Same Docker image, same configs
- **Conclusion**: Issue is environmental/runtime, not code-based

### 9. Pattern Recognition
- =� **Critical Finding**: After multiple tests, discovered that even NEW clients deployed on previously working servers cannot save function pipes
- =� **Pattern**: All failures involve containerized nginx
- **Hypothesis**: Issue is related to nginx running in Docker container

## Current Hypothesis

The issue appears to be related to **nginx running as a Docker container** proxying requests to Open WebUI. Specific possibilities:

1. **HTTP/2 to HTTP/1.1 downgrade issue**
   - nginx receives HTTP/2 from browser
   - Proxies as HTTP/1.1 to Open WebUI
   - Something in the transformation breaks `/api/v1/utils/code/format` requests

2. **Request buffering or size limits**
   - Function pipe code might hit buffer limits
   - nginx configuration has `proxy_buffering off` but may need additional tuning

3. **WebSocket upgrade issues**
   - nginx template includes WebSocket support
   - `/api/v1/utils/code/format` might need special handling

4. **State/timing issue in nginx container**
   - Works initially on new deployments
   - Fails after some condition is met (time, requests, state change)

## nginx Configuration (Current)

### Relevant nginx Settings
```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;

    location / {
        proxy_pass http://${CONTAINER_NAME}:8080;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';

        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 100M;
    }
}
```

### Template File
- Location: `mt/nginx-container/nginx-template-containerized.conf`
- nginx version: 1.29.2
- Running in: Docker container on custom bridge network

## Technical Context

### Deployment Architecture
```
Browser (HTTPS/HTTP2)
    �
nginx Docker Container (port 443)
    � (HTTP/1.1 proxy)
Open WebUI Docker Container (port 8080)
    �
uvicorn (FastAPI backend)
```

### Network Flow
1. Browser sends HTTPS request to nginx (HTTP/2)
2. nginx terminates SSL, downgrades to HTTP/1.1
3. nginx proxies to Open WebUI container via Docker network
4. uvicorn processes request
5. Response flows back through nginx to browser

### The Failing Endpoint
- **Endpoint**: `POST /api/v1/utils/code/format`
- **Purpose**: Format/validate Python code in function pipes before saving
- **Expected**: JSON response with formatted code
- **Actual**: Plain text error "Invalid HTTP request received."

## Files Referenced

- `/Users/justinmartin/github/open-webui/mt/client-manager.sh` - Client deployment script
- `/Users/justinmartin/github/open-webui/mt/nginx-container/nginx-template-containerized.conf` - nginx config template
- `/Users/justinmartin/github/open-webui/mt/pipes/do-function-pipe.py` - Example pipe being tested

## Test Servers

### Production (Failing)
- **Host**: 104.236.102.26
- **Access**: `ssh root@104.236.102.26`
- **Domain**: chat.blanecanada.ai
- **Container**: openwebui-chat-blanecanada-ai

### Development (Working - chat-test-01)
- **Domain**: chat-test-01.quantabase.io
- **Status**: Pipe saves successfully

## Workarounds Attempted

None successful yet.

## Next Investigation Steps

### Option 1: nginx Request Logging
Enable detailed nginx logging to see exactly what's being sent to Open WebUI:
```nginx
log_format detailed '$remote_addr - $remote_user [$time_local] '
                   '"$request" $status $body_bytes_sent '
                   '"$http_referer" "$http_user_agent" '
                   '$request_time $upstream_response_time '
                   '$request_body';
access_log /var/log/nginx/detailed.log detailed;
```

### Option 2: Test Without nginx
Deploy Open WebUI directly exposed (port 8080) to verify nginx is the issue:
1. Temporarily expose Open WebUI port 8080 directly
2. Test pipe save at `http://<server-ip>:8080`
3. If works: confirms nginx is the problem
4. If fails: issue is in Open WebUI itself

### Option 3: Alternative nginx Configuration
Try different proxy settings:
```nginx
# Keep HTTP/2 to backend?
proxy_http_version 2;

# Or force HTTP/1.0?
proxy_http_version 1.0;

# Increase buffer sizes?
proxy_buffers 8 16k;
proxy_buffer_size 16k;
```

### Option 4: Check Open WebUI Logs During Failure
Monitor Open WebUI container logs in real-time during save attempt:
```bash
docker logs -f openwebui-chat-blanecanada-ai
```
Look for FastAPI/uvicorn error details beyond "Invalid HTTP request received."

### Option 5: Compare Working vs Failing nginx Logs
- Enable same detailed logging on working server
- Compare request headers, timing, body handling
- Look for differences in how requests are processed

### Option 6: Test with Non-Containerized nginx
- Deploy nginx directly on host (not in container)
- Use same configuration
- Determine if containerization is the issue

### Option 7: Network Packet Capture
Use tcpdump to capture traffic between nginx and Open WebUI:
```bash
# Inside nginx container or host
tcpdump -i any -w /tmp/nginx-openwebui.pcap port 8080
```
Analyze with Wireshark to see exact HTTP exchange.

## Related Issues

This error is similar to the issue encountered earlier when troubleshooting unpinned Docker images, which was ultimately resolved by:
1. Pinning to a specific working Docker image
2. Clearing browser cache

However, this time:
- Image is already pinned and verified working
- Browser cache is not the issue (incognito fails)
- Pattern suggests runtime/environmental cause

## Additional Context

### User Observations
- "After several tests I am finding that even when I build a new client on the previously working servers that I cannot save the function pipe"
- "I am suspecting that the issue is related to using nginx in a docker container"
- User tested with "production deployment which was supposed to have resolved the issue, but it still errors"

### Let's Encrypt Rate Limiting
- User hit Let's Encrypt production rate limits during testing
- Resolved by adding staging certificate option in client-manager.sh
- Committed in: `feat: Add Let's Encrypt production/staging certificate selection`

## Resolution Criteria

Issue will be considered resolved when:
1. Function pipes can be saved successfully through containerized nginx
2. No JSON parsing errors in browser
3. `/api/v1/utils/code/format` endpoint returns proper JSON responses
4. Solution works consistently across all deployments
5. Root cause is understood and documented

## Impact

**Severity**: HIGH
- Blocks ability to save custom function pipes
- Affects ALL containerized nginx deployments
- Spreading to previously working servers
- No current workaround

**Affected Functionality**:
- Function pipe creation/editing in Admin panel
- Code formatting/validation endpoint

**Not Affected**:
- OAuth authentication (working)
- SSL certificates (working)
- Basic Open WebUI functionality (working)
- Chat functionality (assumed working)
