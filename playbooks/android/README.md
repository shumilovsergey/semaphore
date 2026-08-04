[<- Назад ](../../README.md)

## Android — `playbooks/android/`

Плейбуки для телефона под бэкапы (rsync, зеркала git и прочее хранение).

Цель — **Termux напрямую**, без Debian в proot.

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

Публичный ключ берётся с сервера Semaphore — тот, что напечатал
`tools/ansible-server-init.sh` (`/home/ansible/.ssh/id_ed25519.pub`).
`tools/ansible-client-init.sh` на телефоне **не запускается**: там нет ни
`useradd`, ни `sudo`, ни `/etc`.

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

- `ansible_python_interpreter` — без него Ansible ищет `/usr/bin/python3`, которого нет.
- `ansible_shell_executable` — Ansible по умолчанию зовёт `/bin/sh`. На Android
  это шелл системы (toybox) с чужим PATH, а не шелл Termux.
- отдельная группа `[android]` — чтобы телефон не попал под `run.yml` с
  `target: home`. Там `become: true` и `preflight`, который сверяет
  `ansible_hostname` с именем в inventory: на Termux это сразу падает.
- `ansible_remote_tmp` и `ansible_async_dir` — абсолютными. В Termux нет записи
  в passwd для `u0_aXXX`, а Ansible разворачивает `~` не сам, а через remote
  `echo ~u0_a226`. Bash не резолвит имя и отдаёт строку как есть, после чего
  Ansible принимает `~u0_a226` за настоящий путь. `async` от этого ломается с
  `could not find job`. В `playbooks/android/*.yml` эти переменные тоже
  проставлены — inventory живёт вне git и может протухнуть.

**`u0_a226` — это uid, который Android выдал приложению при установке.**
Переустановишь Termux — номер сменится, и inventory молча протухнет.
Проверять через `whoami`.

### Что делать с батареей

Android усыпляет Termux (Doze, app standby), процессы замирают, а ssh-соединение
остаётся открытым — снаружи это выглядит как вечно висящая задача.

- `termux-wake-lock` — плейбуки берут его сами на время работы;
- отключить оптимизацию батареи для Termux в настройках Android;
- **Termux:Boot** — поднимать `sshd` после перезагрузки телефона;
- на стороне Semaphore держать `ServerAliveInterval`, чтобы обрыв связи
  становился ошибкой, а не бесконечным ожиданием.

### Куда нельзя класть данные

`/sdcard`, `/storage`, `~/storage/*` — это FUSE-монтирование без симлинков,
хардлинков и битов прав. Git-репозиторий там разваливается. Зеркала и любые
репозитории держим во внутренней памяти Termux
(`/data/data/com.termux/files/home`). Для целей rsync общее хранилище годится,
если не тащить туда права (`--no-perms --no-owner --no-group`).
