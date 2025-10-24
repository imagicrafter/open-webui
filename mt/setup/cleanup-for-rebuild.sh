#!/bin/bash
# Cleanup script to restore Digital Ocean droplet to fresh state
# This allows re-running quick-setup.sh without destroying the droplet
#
# Usage:
#   sudo bash cleanup-for-rebuild.sh
#
# What this does:
#   - Stops and removes all Open WebUI containers
#   - Removes all Open WebUI Docker volumes
#   - Removes openwebui-network
#   - Removes /opt/openwebui-nginx directory
#   - Removes qbmgr user and home directory
#   - Removes qbmgr sudoers file
#
# What this preserves:
#   - Root SSH access and keys
#   - Docker installation
#   - System packages (certbot, jq, htop, etc.)
#   - SSL certificates in /etc/letsencrypt (optional cleanup)
#   - Network configuration and Cloudflare DNS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}Droplet Cleanup for Quick-Setup Rebuild${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Usage: sudo bash cleanup-for-rebuild.sh"
    exit 1
fi

# Confirmation prompt
echo -e "${YELLOW}WARNING: This will remove:${NC}"
echo "  - All Open WebUI containers and volumes"
echo "  - qbmgr user and home directory"
echo "  - /opt/openwebui-nginx directory"
echo
echo -e "${GREEN}This will preserve:${NC}"
echo "  - Root SSH access"
echo "  - Docker installation"
echo "  - System packages"
echo "  - SSL certificates (unless you choose to remove them)"
echo
read -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo

# Stop and remove all Open WebUI containers
echo -e "${BLUE}[1/8] Stopping and removing Open WebUI containers...${NC}"
CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep -E '^openwebui-' || true)
if [ -n "$CONTAINERS" ]; then
    echo "$CONTAINERS" | while read container; do
        echo "  Stopping $container..."
        docker stop "$container" 2>/dev/null || true
        echo "  Removing $container..."
        docker rm "$container" 2>/dev/null || true
    done
    echo -e "${GREEN}✅ Containers removed${NC}"
else
    echo "  No Open WebUI containers found"
fi

# Remove Open WebUI Docker volumes
echo -e "${BLUE}[2/8] Removing Open WebUI Docker volumes...${NC}"
VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -E '^openwebui-' || true)
if [ -n "$VOLUMES" ]; then
    echo "$VOLUMES" | while read volume; do
        echo "  Removing volume $volume..."
        docker volume rm "$volume" 2>/dev/null || true
    done
    echo -e "${GREEN}✅ Volumes removed${NC}"
else
    echo "  No Open WebUI volumes found"
fi

# Remove Docker network
echo -e "${BLUE}[3/8] Removing openwebui-network...${NC}"
if docker network inspect openwebui-network >/dev/null 2>&1; then
    docker network rm openwebui-network 2>/dev/null || true
    echo -e "${GREEN}✅ Network removed${NC}"
else
    echo "  Network doesn't exist"
fi

# Remove nginx config directory
echo -e "${BLUE}[4/8] Removing /opt/openwebui-nginx...${NC}"
if [ -d "/opt/openwebui-nginx" ]; then
    rm -rf /opt/openwebui-nginx
    echo -e "${GREEN}✅ nginx config directory removed${NC}"
else
    echo "  Directory doesn't exist"
fi

# Optional: Remove SSL certificates
echo
read -p "Also remove SSL certificates from /etc/letsencrypt? (y/N): " remove_ssl
if [[ "$remove_ssl" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}[5/8] Removing SSL certificates...${NC}"
    rm -rf /etc/letsencrypt
    echo -e "${GREEN}✅ SSL certificates removed${NC}"
else
    echo -e "${BLUE}[5/8] Preserving SSL certificates...${NC}"
    echo -e "${GREEN}✅ SSL certificates preserved${NC}"
fi

# Remove qbmgr user's home directory and repo
echo -e "${BLUE}[6/8] Removing qbmgr home directory...${NC}"
if [ -d "/home/qbmgr" ]; then
    rm -rf /home/qbmgr
    echo -e "${GREEN}✅ Home directory removed${NC}"
else
    echo "  Home directory doesn't exist"
fi

# Remove qbmgr from sudoers
echo -e "${BLUE}[7/8] Removing qbmgr from sudoers...${NC}"
if [ -f "/etc/sudoers.d/qbmgr" ]; then
    rm -f /etc/sudoers.d/qbmgr
    echo -e "${GREEN}✅ Sudoers file removed${NC}"
else
    echo "  Sudoers file doesn't exist"
fi

# Delete qbmgr user
echo -e "${BLUE}[8/8] Removing qbmgr user...${NC}"
if id "qbmgr" &>/dev/null; then
    userdel qbmgr 2>/dev/null || true
    echo -e "${GREEN}✅ User removed${NC}"
else
    echo "  User doesn't exist"
fi

echo
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${BLUE}==================================================${NC}"
echo
echo "Droplet is now in clean state. Ready to run quick-setup:"
echo
echo -e "${GREEN}For test server (main branch):${NC}"
echo '  curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash -s -- "" "test"'
echo
echo -e "${BLUE}For production server (release branch):${NC}"
echo '  curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash -s -- "" "production"'
echo
echo -e "${YELLOW}Note:${NC} Root SSH access, Docker, and system packages remain intact."
echo
