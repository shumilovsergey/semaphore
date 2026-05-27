#!/bin/bash

set -e

# ==========================================
# Semaphore Ansible Client Bootstrap
# ==========================================

# ANSIBLE_IP=""

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

# Запрос публичного ключа
echo "Введите публичный SSH ключ для пользователя: $USER"
echo
echo "Пример:"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
echo

read -r -p "SSH public key: " SSH_KEY < /dev/tty

if [ -z "$SSH_KEY" ]; then
    echo
    echo "SSH ключ не может быть пустым ❌"
    exit 1
fi

echo
echo "[0/5] Проверка пользователя..."

if id "$USER" &>/dev/null; then
    echo "Пользователь $USER уже существует ✅"
else
    echo "Пользователь $USER не найден. Создаём..."

    useradd -m -s /bin/bash "$USER"

    # (опционально) добавить в sudo группу
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

# echo
# echo "[5/5] Разрешаю SSH от Ansible-сервера: $ANSIBLE_IP"
# ufw allow from "$ANSIBLE_IP" to any port 22 proto tcp comment 'ansible ssh'
# ufw reload

echo
echo "=========================================="
echo " Setup completed successfully ✅"
echo "=========================================="
echo
echo " SSH access configured for user: $USER"
echo