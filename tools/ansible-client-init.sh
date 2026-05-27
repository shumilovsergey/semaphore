#!/bin/bash

set -e

# ANSIBLE_IP=""

USER="ansible"

echo "=========================================="
echo " Enter public SSH key for user: $USER"
echo "=========================================="
echo

read -p "SSH public key: " SSH_KEY

echo
echo "[0/5] Проверка пользователя..."

if id "$USER" &>/dev/null; then
    echo "Пользователь $USER уже существует ✅"
else
    echo "Пользователь $USER не найден. Создаём..."

    sudo useradd -m -s /bin/bash "$USER"

    # (опционально) добавить в sudo группу
    if getent group sudo >/dev/null; then
        sudo usermod -aG sudo "$USER"
    elif getent group wheel >/dev/null; then
        sudo usermod -aG wheel "$USER"
    fi

    echo "Пользователь создан ✅"
fi

echo
echo "[1/5] Настройка sudo без пароля..."

echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible > /dev/null
sudo chmod 440 /etc/sudoers.d/ansible

echo "Sudo настроен ✅"

echo
echo "[2/5] Создание .ssh директории..."

sudo mkdir -p /home/$USER/.ssh

echo ".ssh директория готова ✅"

echo
echo "[3/5] Добавление SSH ключа..."

echo "$SSH_KEY" | sudo tee /home/$USER/.ssh/authorized_keys > /dev/null

echo "SSH ключ добавлен ✅"

echo
echo "[4/5] Настройка прав..."

sudo chmod 700 /home/$USER/.ssh
sudo chmod 600 /home/$USER/.ssh/authorized_keys
sudo chown -R $USER:$USER /home/$USER/.ssh

echo "Права настроены ✅"

# echo
# echo "[5/5] Разрешаю SSH от Ansible-сервера: $ANSIBLE_IP"
# ufw allow from "$ANSIBLE_IP" to any port 22 proto tcp comment 'ansible ssh'
# ufw reload

echo
echo "=========================================="
echo " Setup completed successfully ✅"
echo "=========================================="