#!/bin/bash
# Quick Setup for Open WebUI Deployment
# Run this as root on a fresh Digital Ocean droplet - NO PROMPTS, JUST WORKS
#
# Usage Option 1 (auto-copy SSH key from root):
#   curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash
#
# Usage Option 2 (provide SSH key):
#   curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash -s -- "YOUR_SSH_PUBLIC_KEY"

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DEPLOY_USER="qbmgr"
REPO_URL="https://github.com/imagicrafter/open-webui.git"
SSH_KEY="${1:-}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Open WebUI Quick Setup (Non-Interactive)              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo
    echo "Usage:"
    echo "  curl -fsSL https://raw.githubusercontent.com/imagicrafter/open-webui/main/mt/setup/quick-setup.sh | bash"
    exit 1
fi

# Determine SSH key source
if [ -z "$SSH_KEY" ]; then
    if [ -f /root/.ssh/authorized_keys ]; then
        echo -e "${YELLOW}No SSH key provided - will copy from root's authorized_keys${NC}"
        COPY_FROM_ROOT=true
    else
        echo -e "${RED}❌ No SSH key provided and root has no authorized_keys${NC}"
        echo
        echo "Either:"
        echo "  1. Provide SSH key: curl ... | bash -s -- \"YOUR_SSH_KEY\""
        echo "  2. Ensure root has SSH keys in /root/.ssh/authorized_keys"
        exit 1
    fi
else
    # Validate SSH key format
    if [[ ! "$SSH_KEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ]]; then
        echo -e "${RED}❌ Invalid SSH key format${NC}"
        echo "SSH key should start with 'ssh-rsa', 'ssh-ed25519', or 'ecdsa-sha2-nistp256'"
        exit 1
    fi
    COPY_FROM_ROOT=false
fi

# Step 1: Create user if doesn't exist
echo -e "${BLUE}[1/8] Creating user '$DEPLOY_USER'...${NC}"
if id "$DEPLOY_USER" &>/dev/null; then
    echo -e "${YELLOW}User already exists, continuing...${NC}"
else
    useradd -m -s /bin/bash "$DEPLOY_USER"
    echo -e "${GREEN}✅ User created${NC}"
fi

# Step 2: Add to sudo and docker groups
echo -e "${BLUE}[2/8] Configuring groups (sudo, docker)...${NC}"
usermod -aG sudo "$DEPLOY_USER"
usermod -aG docker "$DEPLOY_USER"
echo -e "${GREEN}✅ Groups configured${NC}"

# Step 3: Configure passwordless sudo
echo -e "${BLUE}[3/8] Enabling passwordless sudo...${NC}"
echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$DEPLOY_USER"
chmod 0440 "/etc/sudoers.d/$DEPLOY_USER"
echo -e "${GREEN}✅ Passwordless sudo enabled${NC}"

# Step 4: Set up SSH key
echo -e "${BLUE}[4/8] Setting up SSH access...${NC}"
# Fix home directory permissions (SSH requires 755 or 700)
chmod 755 "/home/$DEPLOY_USER"
mkdir -p "/home/$DEPLOY_USER/.ssh"

if [ "$COPY_FROM_ROOT" = true ]; then
    # Copy SSH keys from root
    cp /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
    echo -e "${GREEN}✅ SSH keys copied from root${NC}"
else
    # Normalize SSH key to single line (remove any newlines/whitespace issues)
    SSH_KEY_CLEAN=$(echo "$SSH_KEY" | tr -d '\n\r' | tr -s ' ')
    echo "$SSH_KEY_CLEAN" > "/home/$DEPLOY_USER/.ssh/authorized_keys"
    echo -e "${GREEN}✅ SSH key configured${NC}"
fi

chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
chmod 700 "/home/$DEPLOY_USER/.ssh"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

# Step 4.5: Configure auto-start of client-manager on login
echo -e "${BLUE}[4.5/8] Configuring client-manager auto-start...${NC}"
cat > "/home/$DEPLOY_USER/.bash_profile" << 'BASH_PROFILE_EOF'
# Auto-start client-manager on interactive SSH login
if [[ -n "$SSH_CONNECTION" ]] || [[ -n "$SSH_CLIENT" ]]; then
    # Check if this is an interactive shell
    if [[ $- == *i* ]]; then
        cd ~/open-webui/mt 2>/dev/null && ./client-manager.sh
    fi
fi

# Source bashrc for environment setup
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
BASH_PROFILE_EOF

chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.bash_profile"
chmod 644 "/home/$DEPLOY_USER/.bash_profile"
echo -e "${GREEN}✅ Auto-start configured${NC}"

# Step 5: Clone Open WebUI repository
echo -e "${BLUE}[5/8] Cloning repository...${NC}"
REPO_PATH="/home/$DEPLOY_USER/open-webui"
if [ -d "$REPO_PATH" ]; then
    echo -e "${YELLOW}Repository exists, pulling latest...${NC}"
    sudo -u "$DEPLOY_USER" git -C "$REPO_PATH" pull || true
else
    sudo -u "$DEPLOY_USER" git clone "$REPO_URL" "$REPO_PATH"
fi

# Make scripts executable
chmod +x "$REPO_PATH/mt/client-manager.sh"
chmod +x "$REPO_PATH/mt/nginx-container/deploy-nginx-container.sh"
chmod +x "$REPO_PATH/mt/setup"/*.sh 2>/dev/null || true

echo -e "${GREEN}✅ Repository ready at $REPO_PATH${NC}"

# Step 6: Create directories
echo -e "${BLUE}[6/8] Creating directories...${NC}"
mkdir -p /opt/openwebui-nginx
chown -R "$DEPLOY_USER:$DEPLOY_USER" /opt/openwebui-nginx
echo -e "${GREEN}✅ Created /opt/openwebui-nginx${NC}"

# Step 7: Install packages
echo -e "${BLUE}[7/8] Installing packages (certbot, jq, htop, tree)...${NC}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y certbot jq htop tree net-tools > /dev/null 2>&1
echo -e "${GREEN}✅ Packages installed${NC}"

# Step 8: Create welcome message
echo -e "${BLUE}[8/8] Creating welcome message...${NC}"
cat > "/home/$DEPLOY_USER/WELCOME.txt" << 'EOF'
╔════════════════════════════════════════════════════════════╗
║          Open WebUI Deployment Server Ready                ║
╚════════════════════════════════════════════════════════════╝

✅ Quick setup completed successfully!

Your server is configured with:
  - User: qbmgr (sudo + docker access)
  - Repository: ~/open-webui
  - nginx directory: /opt/openwebui-nginx

Quick Start Commands:

1. Start the client manager:
   cd ~/open-webui/mt
   ./client-manager.sh

2. Deploy nginx (option 2 in menu)
   Then create client deployments (option 3)

3. Check running containers:
   docker ps

Documentation:
  - Quick Start: ~/open-webui/mt/QUICKSTART-FRESH-DEPLOYMENT.md
  - nginx Setup: ~/open-webui/mt/nginx-container/README.md
  - Multi-tenant: ~/open-webui/mt/README.md

Security Note:
  Root SSH is still enabled. After testing qbmgr access, disable it:
  sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sudo systemctl reload sshd

EOF

chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/WELCOME.txt"
echo -e "${GREEN}✅ Welcome message created${NC}"

# Get droplet IP
DROPLET_IP=$(hostname -I | awk '{print $1}')

# Summary
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo
echo "Configuration:"
echo -e "  ${GREEN}✅${NC} User: qbmgr"
echo -e "  ${GREEN}✅${NC} Groups: sudo, docker"
echo -e "  ${GREEN}✅${NC} Repository: /home/qbmgr/open-webui"
if [ "$COPY_FROM_ROOT" = true ]; then
    echo -e "  ${GREEN}✅${NC} SSH keys: Copied from root"
else
    echo -e "  ${GREEN}✅${NC} SSH key: Configured"
fi
echo -e "  ${GREEN}✅${NC} Packages: certbot, jq, htop, tree"
echo -e "  ${GREEN}✅${NC} Auto-start: client-manager on login"
echo
echo -e "${YELLOW}Security Reminder:${NC}"
echo -e "  Root SSH is still enabled. Test qbmgr access first, then disable root SSH."
echo

# Test Docker access
echo -e "${BLUE}Testing Docker access for qbmgr...${NC}"
if sudo -u "$DEPLOY_USER" docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker access verified${NC}"
else
    echo -e "${YELLOW}⚠️  Docker access may require logout/login to activate${NC}"
fi

echo
echo -e "${GREEN}All done! Switching to qbmgr user and starting client-manager...${NC}"
echo
sleep 2

# Switch to qbmgr user and start client-manager
exec su - "$DEPLOY_USER"
