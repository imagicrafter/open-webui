#!/bin/bash
# Fix SSH key for qbmgr user
# Run as root: bash fix-ssh-key.sh

set -e

echo "Fixing SSH key for qbmgr user..."

# Write the correct SSH key on a single line
cat > /home/qbmgr/.ssh/authorized_keys << 'SSHKEY'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDXscwwssZLx9HqaAOQ1Sn7mszqnJAXwMFbVleohyDLKgimzeD5bx6r68xeLpd4P2nqJXdO+j84H63N6acS517ylWzXKlblrGKHo20ka+yByyxyw8c1SzwJeegLb8CC+is+i/P5ydUYxc5BseVv8QLITWAJB351+h+v6wDOPm8DJICbzR+2QvL45t3WHibRiHH4dxpoMge0m9TphCkwz5nYRazGew0bmprfN4/eVpP+b/gertm7/bMN63SZ6P7jWpzlGozgMrMdENZMfSYzBRJfjj4DMwZx4m4GrGyGpqhdIfJZ7qckqwHQitsOMsozUH+pdphLxMouKMoiIFvS+eYxeo9oGJz++oegEk58zE9xOF7dcfJdkFoXvQK/u4su/V/4oCnVb72xT9tdnnNIjn5eHnZ6NNaOinhktaqqoVWsLMtJLHJs4OgmMqc03tSfjVLsCB/XhXXL6WTPsHSi/qtcv7LQdgizi6yx+iyt/LIwTTjvxNyDPE2reNhyxbfLstE= justinmartin@Justins-MacBook-Pro.local
SSHKEY

# Fix permissions
chmod 755 /home/qbmgr
chmod 700 /home/qbmgr/.ssh
chmod 600 /home/qbmgr/.ssh/authorized_keys
chown -R qbmgr:qbmgr /home/qbmgr/.ssh

echo "✅ SSH key fixed!"
echo "✅ Permissions corrected"
echo ""
echo "Try SSH now: ssh qbmgr@YOUR_DROPLET_IP"
