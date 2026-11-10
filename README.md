## Semaphore

![cover](/tools/baner.webp)

## Структура репозитория

```
ansible.cfg             — конфигурация
run.yml                 — главный плейбук: разворачивает servers/<hostname>.yml по target

playbooks/              — уникальные задачи под конкретные ситуации

roles/                  — переиспользуемые рецепты (не знают про конкретные серверы)
  0_role_template/      — шаблон для новой роли
    defaults/           — переменные по умолчанию
    tasks/              — шаги выполнения
    handlers/           — запускаются после tasks при изменениях
    files/              — статические файлы
    templates/          — jinja2 шаблоны (.j2)

servers/                — конфигурация серверов
  <hostname>.yml        — роли и переменные конкретного сервера

inventory-cli/          - вспомогательная CLI (описание ниже)

inventory/host.ini      - парк машин

tools/                  — все что не ansible
```

## Установка и запуск Semaphore. GUI для управления Ansible инфраструктурой.

- Создать ansible пользователя на сервере

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/ansible-server-init.sh | sudo bash
```

- Создать ansible пользователя на клиенте

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/ansible-client-init.sh -o /tmp/ansible-client-init.sh && sudo bash /tmp/ansible-client-init.sh "PUT_HERE_PUBKEY" "OPTIONAL-IP-ALLOW-UFW-RULE"
```


- [Установка Semaphore](./tools/install.md)

- [Подробнее про роли](./roles/README.md)

- [Подробнее про сервера](./servers/README.md)

- [Подключение TOTP](./tools/totp.md)

- [Публичный репозиторий ролей](./tools/sync_shumilov_roles.md)

- [Шорткаты для manual.sh скриптов](./tools/manual_bash_shortcuts.md)

- [inventory-cli](./inventory-cli/README.md)


