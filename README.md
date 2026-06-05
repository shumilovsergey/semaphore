## Semaphore

![cover](./tools/cover.png)

## Установка и запуск Semaphore. GUI для управления Ansible инфраструктурой.


- Создать ansible пользователя на сервере

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/scripts/ansible-server-init.sh | sudo bash
```

- Создать ansible пользователя на клиенте

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/scripts/ansible-client-init.sh | sudo bash -s "PUT_HERE_PUBKEY"
```


- [Установка Semaphore](./scripts/install.md)

- [Структара playbooks](./temp/README.md)

