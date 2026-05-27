# Semaphore

![cover](./tools/cover.png)

Установка и запуск Semaphore. GUI для управления Ansible инфраструктурой.
---

- [Установка Semaphore](./tools/install.md)

- Создать ansible пользователя на сервере

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/ansible-server-init.sh | sudo bash
```

- Создать ansible пользователя на клиенте

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/ansible-client-init.sh | sudo bash
```