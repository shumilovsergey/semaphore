[<- Назад ](../README.md)

## Включение TOTP

Добавить на первый уровень `/etc/semaphore/config.json`:

```json
"auth": {
  "totp": {
    "enabled": true,
    "allow_recovery": true,
    "issuer": "Semaphore"
  }
}
```

Перезапустить сервис:

```bash
systemctl restart semaphore
```


## Список пользователей

```bash
semaphore users list
```


## Создать QR-код для пользователя

```bash
semaphore users totp enable --login <username>
```

Команда выведет QR-код для привязки к Google Authenticator, Aegis и т.п.


## Посмотреть статус пользователя

Информация о пользователе:

```bash
semaphore users get --login <username>
```

Информация о TOTP:

```bash
semaphore users totp show --login <username>
```


## Отключить TOTP

```bash
semaphore users totp disable --login <username>
```