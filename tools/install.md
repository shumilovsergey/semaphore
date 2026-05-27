## Установка

Скачать
```bash
VER=$(curl -s https://api.github.com/repos/semaphoreui/semaphore/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//g')

wget https://github.com/semaphoreui/semaphore/releases/download/v${VER}/semaphore_${VER}_linux_amd64.deb
```

Установить
```bash
apt update
apt install ansible -y

apt install ./semaphore_${VER}_linux_amd64.deb
```

Проверить 
```bash
which semaphore
semaphore version

ansible-playbook --version
```

Настройка
```bash
mkdir -p /etc/semaphore
cd /etc/semaphore

semaphore setup
```

Настройка порта
```nano
nano /etc/semaphore/config.json
```

Добавить на нижний уровень
```bash
"port": "PORT",
```

Создать службу
```bash
cat >/etc/systemd/system/semaphore.service <<EOF
[Unit]
Description=Semaphore UI
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/semaphore server --config /etc/semaphore/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Запуск и проверка
```bash
systemctl daemon-reload
systemctl enable semaphore
systemctl start semaphore
systemctl status semaphore
```

