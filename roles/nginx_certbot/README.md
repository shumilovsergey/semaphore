[<- Назад ](../README.md)

## Роль `nginx_certbot`

Создаёт reverse-proxy конфиги в `/etc/nginx/conf.d/` и выпускает под них сертификаты Let's Encrypt через `certbot --nginx`.

nginx и certbot (`certbot`, `python3-certbot-nginx`) должны быть **уже установлены** — роль их не ставит, а проверяет наличие и падает с понятной ошибкой, если их нет.

### Переменные

| Переменная | Что это |
|---|---|
| `nginx_sites` | список сайтов (см. ниже) |
| `certbot_email` | email для Let's Encrypt, обязателен если есть сайты |
| `vpn_allow_ip` | IP, которому разрешён доступ при `vpn_only: true` |
| `conf_dir` | каталог конфигов, по умолчанию `/etc/nginx/conf.d` |

Поля сайта: `name` (имя файла → `<name>.conf`), `domain` (server_name + домен для certbot), `port` (локальный порт для proxy_pass), `vpn_only` (true → доступ только с `vpn_allow_ip`).

### Пример в `servers/<hostname>.yml`

```yaml
server_roles:
  - nginx_certbot

certbot_email: admin@expoforum.ru
vpn_allow_ip: 5.189.254.175

nginx_sites:
  - name: app
    domain: app.domain.com
    port: 8080
    vpn_only: false
  - name: admin
    domain: admin.domain.com
    port: 9000
    vpn_only: true
```

### Как это работает

1. Шаблон пишет HTTP-конфиг (`listen 80`) — **только если файла ещё нет** (`force: false`).
2. `nginx -t` + reload, чтобы certbot увидел живой блок для ACME-челленджа.
3. `certbot --nginx` выпускает сертификат и **сам дописывает** в конфиг блок `listen 443` и редирект — один раз (гард по `/etc/letsencrypt/live/<domain>/fullchain.pem`).

Повторные прогоны идемпотентны: конфиг не перетирается, сертификат не перевыпускается.

### Важно

- **Домен должен резолвиться на публичный IP сервера, а порт 80 быть открыт снаружи** — иначе ACME-челлендж не пройдёт и certbot упадёт.
- Так как certbot дописывает SSL прямо в файл, роль его потом не трогает. **Чтобы изменить порт/домен/`vpn_only` существующего сайта — удали его `<name>.conf` и запусти роль заново** (сертификат переиспользуется).
