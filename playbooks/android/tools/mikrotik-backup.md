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
flash/backup/mikrotik/          # рабочая копия, забирается Ansible
usb1/backups/mikrotik/    # резервная копия на USB
```

## Ротация

Ротация намеренно упрощенная. 
Используется циклическая схема по дню месяца:

``` text
date-01.backup
ate-02.backup
...
date-31.backup
```

## Backup script

```
/system script set make-backup source={
    # MikroTik automated rotating backup
    #
    # Tested on:
    #   Device: MikroTik hAP ac^2
    #   RouterOS: 7.18.2 (stable)
    #
    # Rotation:
    #   date-01.backup ... date-31.backup

    :local date [/system clock get date]
    :local day [:pick $date 8 10]
    :local name ("date-" . $day)

    /system backup save name=("flash/backup/mikrotik/" . $name)

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

Папки:

```routeros
# flash
/file add name=flash/backup type=directory
/file add name=flash/backup/mikrotik type=directory

# usb
/file add name=usb1/backup type=directory
/file add name=usb1/backup/mikrotik type=directory
```



## Ручная проверка

``` routeros
/system script run make-backup
```

Проверка:

``` routeros
/file print where name~"sh-mikrotik-date-"
```

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

## Итоговая схема

Scheduler (22:00 UTC / 01:00 MSK)
              |
              v
         make-backup
          /       \
         v         v
flash/backup/       usb1/backup/
mikrotik/           mikrotik/
date-01..31         date-01..31
     |
     v
   Ansible
