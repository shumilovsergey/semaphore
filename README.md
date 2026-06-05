## Semaphore

![cover](./tools/cover.png)

## Структура репозитория

```
playbooks/          — уникальные задачи под конкретные приложения
  web_apps/
  github_clone.yml

roles/              — переиспользуемые рецепты (не знают про конкретные серверы)
  0_role_template/  — шаблон для новой роли (скопируй и переименуй)
    defaults/       — переменные по умолчанию
    tasks/          — шаги выполнения
    handlers/       — запускаются после tasks при изменениях
    files/          — статические файлы
    templates/      — jinja2 шаблоны (.j2)

servers/            — конфигурация серверов
  all.yml           — роли и переменные для всех серверов
  <hostname>.yml    — роли и переменные конкретного сервера

tools/            — не-ansible: скрипты инициализации, гайды
```

## Установка и запуск Semaphore. GUI для управления Ansible инфраструктурой.


- Создать ansible пользователя на сервере

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/ansible-server-init.sh | sudo bash
```

- Создать ansible пользователя на клиенте

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/ansible-client-init.sh | sudo bash -s "PUT_HERE_PUBKEY"
```


- [Установка Semaphore](./tools/install.md)

- [Подробнее про роли](./roles/README.md)

- [Публичный репозиторий ролей](./tools/sync_shumilov_roles.md)



