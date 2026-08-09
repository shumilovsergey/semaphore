[<- Назад ](../../README.md)

## Android — `playbooks/android/`

Плейбуки для телефона под бэкапы (rsync, зеркала git и прочее хранение).

### Подключение

В Termux:

```bash
pkg install openssh python git rsync
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAA... ansible@semaphore' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
sshd                 # слушает 8022
whoami               # даст ansible_user, например u0_a226
```

Проверка с сервера Semaphore:

```bash
sudo -u ansible ssh -p 8022 u0_a226@10.10.20.14 'echo ok'
```

### Inventory в Semaphore

Termux — не FHS-система, поэтому хосту нужны свои переменные подключения.

```ini
[home]
sh-homelab ansible_host=10.10.30.165

[android]
seeker ansible_host=10.10.20.14 ansible_port=8022

[android:vars]
ansible_user=u0_a226
ansible_python_interpreter=/data/data/com.termux/files/usr/bin/python
ansible_shell_executable=/data/data/com.termux/files/usr/bin/bash
ansible_remote_tmp=/data/data/com.termux/files/home/.ansible/tmp
ansible_async_dir=/data/data/com.termux/files/home/.ansible_async
ansible_become=false
```

**`u0_a226` — это uid, который Android выдал приложению при установке.**
Проверять через `whoami`.
