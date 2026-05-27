#!/bin/bash

set -e

USERNAME="ansible"
HOME_DIR="/home/$USERNAME"
SSH_KEY="$HOME_DIR/.ssh/id_ed25519"

echo "[+] Creating user: $USERNAME"

useradd -m -s /bin/bash "$USERNAME"

passwd -d "$USERNAME"
passwd -l "$USERNAME"

echo "[+] Configuring sudo access"

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME
visudo -cf /etc/sudoers.d/$USERNAME

echo "[+] Generating SSH key"

sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.ssh"

sudo -u "$USERNAME" ssh-keygen \
  -t ed25519 \
  -f "$SSH_KEY" \
  -N "" \
  -q

PUB_KEY=$(cat "$SSH_KEY.pub")

echo
echo "=========================================="
echo " SSH public key for user: $USERNAME"
echo "=========================================="
echo
echo "$PUB_KEY"
echo
echo "=========================================="