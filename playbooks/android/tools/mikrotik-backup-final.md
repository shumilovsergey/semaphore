# MikroTik Backup Setup

## Проверенная конфигурация

-   **Устройство:** MikroTik hAP ac²
-   **RouterOS:** 7.18.2 (stable)
-   **Архитектура:** ARM
-   **Хранилище:** RAM filesystem + USB (`usb1`)

> Дата и время MikroTik должны быть корректно настроены (например, через
> NTP), так как номер дня используется в имени backup-файла.

## Схема хранения

``` text
backup/mikrotik/          # рабочая копия, забирается Ansible
usb1/backups/mikrotik/    # резервная копия на USB
```

Ansible продолжает использовать существующий путь `/backup/...`.

## Каталоги

``` routeros
/file add name=backup type=directory
/file add name=backup/mikrotik type=directory
/file add name=usb1/backups/mikrotik type=directory
```

Проверка:

``` routeros
/file print where name~"backup"
```

## Ротация

Используется циклическая схема по дню месяца:

``` text
sh-mikrotik-date-01.backup
sh-mikrotik-date-02.backup
...
sh-mikrotik-date-31.backup
```

Каждый день создаётся файл с номером текущего дня. В следующем месяце
файл с тем же номером перезаписывается.

Таким образом хранится максимум 31 дневной backup без отдельной логики
ротации.

Например, 14-го числа:

``` text
01..14  # текущий месяц
15..31  # предыдущий месяц
```

## Backup script

``` routeros
/system script set make-backup source={
    # MikroTik automated rotating backup
    #
    # Tested on:
    #   Device: MikroTik hAP ac^2
    #   RouterOS: 7.18.2 (stable)
    #   Architecture: ARM
    #
    # Backup locations:
    #   RAM: backup/mikrotik/
    #   USB: usb1/backups/mikrotik/
    #
    # Rotation:
    #   sh-mikrotik-date-01.backup ... sh-mikrotik-date-31.backup

    :local date [/system clock get date]
    :local day [:pick $date 8 10]
    :local name ("sh-mikrotik-date-" . $day)

    /system backup save name=("backup/mikrotik/" . $name)

    :delay 2s

    /system backup save name=("usb1/backups/mikrotik/" . $name)

    :log info ("Backup created: " . $name)
}
```

Если скрипта ещё нет:

``` routeros
/system script add name=make-backup \
    policy=read,write,policy,test,sensitive \
    source={ ... }
```

## Ручная проверка

``` routeros
/system script run make-backup
```

Проверка:

``` routeros
/file print where name~"sh-mikrotik-date-"
```

Например, 22-го числа:

``` text
backup/mikrotik/sh-mikrotik-date-22.backup
usb1/backups/mikrotik/sh-mikrotik-date-22.backup
```

Повторный запуск в тот же день перезаписывает backup этого дня.

## Scheduler

MikroTik работает в UTC. Требуемое время backup --- **01:00 MSK**,
поэтому scheduler запускается в **22:00 UTC**.

``` routeros
/system scheduler add \
    name=daily-backup \
    start-time=22:00:00 \
    interval=1d \
    on-event="/system script run make-backup" \
    policy=read,write,policy,test,sensitive
```

Проверка:

``` routeros
/system scheduler print detail where name="daily-backup"
```

Ожидаемые параметры:

``` text
start-time=22:00:00
interval=1d
on-event="/system script run make-backup"
```

## Пользователь Ansible

Используется отдельный пользователь `ansible` с SSH ED25519 key.

Группа:

``` routeros
/user group add name=ansible-full \
    policy=ssh,reboot,read,write,policy,test,password,sniff,sensitive,romon
```

Проверка ключа:

``` routeros
/user/ssh-keys print detail where user=ansible
```

Проверка SSH:

``` bash
ssh ansible@10.10.30.1
```

## Итоговая схема

``` text
Scheduler (22:00 UTC / 01:00 MSK)
              |
              v
         make-backup
          /       \
         v         v
backup/mikrotik/   usb1/backups/mikrotik/
   sh-mikrotik-       sh-mikrotik-
   date-01..31         date-01..31
       |
       v
     Ansible
```

MikroTik создаёт циклический набор до 31 дневной копии в RAM и на USB.
Ansible забирает содержимое `/backup/...` без изменения существующей
схемы.
