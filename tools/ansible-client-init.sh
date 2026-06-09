#!/bin/bash

set -e

# ==========================================
# Semaphore Ansible Client Bootstrap
# ==========================================

USER="ansible"
HOME_DIR="/home/$USER"
SSH_DIR="$HOME_DIR/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

echo "=========================================="
echo " Semaphore Ansible Client Setup"
echo "=========================================="
echo

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запускайте скрипт через sudo или от root ❌"
    exit 1
fi

SSH_KEY="$1"
SEMAPHORE_IP="$2"

if [ -z "$SSH_KEY" ] || [ "$SSH_KEY" = "PUT_HERE_PUBKEY" ]; then
    echo "❌ SSH ключ не передан или не заменён."
    echo
    echo "Использование:"
    echo "  curl -fsSL <url> | sudo bash -s \"<ssh public key>\" \"<semaphore ip>\""
    echo
    echo "Пример:"
    echo "  curl -fsSL <url> | sudo bash -s \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...\" \"10.10.30.100\""
    exit 1
fi

echo
echo "[0/5] Проверка пользователя..."

if id "$USER" &>/dev/null; then
    echo "Пользователь $USER уже существует ✅"
else
    echo "Пользователь $USER не найден. Создаём..."

    useradd -m -s /bin/bash "$USER"

    if getent group sudo >/dev/null; then
        usermod -aG sudo "$USER"
    elif getent group wheel >/dev/null; then
        usermod -aG wheel "$USER"
    fi

    echo "Пользователь создан ✅"
fi

echo
echo "[1/5] Настройка sudo без пароля..."

echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

echo "Sudo настроен ✅"

echo
echo "[2/5] Создание .ssh директории..."

mkdir -p "$SSH_DIR"

echo ".ssh директория готова ✅"

echo
echo "[3/5] Добавление SSH ключа..."

echo "$SSH_KEY" > "$AUTHORIZED_KEYS"

echo "SSH ключ добавлен ✅"

echo
echo "[4/5] Настройка прав..."

chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$USER:$USER" "$SSH_DIR"

echo "Права настроены ✅"

echo
echo "[5/5] Проверка UFW..."

if [ -z "$SEMAPHORE_IP" ]; then
    echo "SEMAPHORE_IP не передан — пропускаем ✅"
elif command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow from "$SEMAPHORE_IP" to any port 22 proto tcp comment 'Semaphore'
    echo "UFW правило добавлено для $SEMAPHORE_IP ✅"
else
    echo "UFW не активен — пропускаем ✅"
fi

echo
echo "=========================================="
echo " Setup completed successfully ✅"
echo "=========================================="
echo
echo " SSH access configured for user: $USER"
echo
