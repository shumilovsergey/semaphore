#!/bin/bash
set -euo pipefail

BACKUP_ROOT="/backup"

read -rp "APP_NAME: " APP_NAME
read -rp "DB path: " DB

BACKUP_DIR="$BACKUP_ROOT/$APP_NAME"
BACKUP_SCRIPT="$BACKUP_DIR/backup.sh"
LOG_FILE="/var/log/${APP_NAME}_backup.log"
LOCK_FILE="/var/lock/backups.lock"

mkdir -p "$BACKUP_DIR"

cat > "$BACKUP_SCRIPT" <<EOF
#!/bin/bash
set -euo pipefail

# 0644 на дампы. Явно, а не на умолчании: на части образов у root
# маска строже, и ночной дамп оказался бы нечитаемым.
umask 022

DB="$DB"
BACKUP_DIR="$BACKUP_DIR"

DATE=\$(date +%F_%H-%M-%S)
BACKUP_FILE="\$BACKUP_DIR/${APP_NAME}-\$DATE.db"

mkdir -p "\$BACKUP_DIR"

sqlite3 "\$DB" ".backup '\$BACKUP_FILE'"

# убедиться что файл создан и не пустой
[ -s "\$BACKUP_FILE" ]

# оставить только последние 7 успешных бэкапов
find "\$BACKUP_DIR" -maxdepth 1 -name '${APP_NAME}-*.db' -type f \
    | sort -r \
    | tail -n +8 \
    | xargs -r rm -f
EOF

#----- ПРАВА

chmod +x "$BACKUP_SCRIPT"
chmod -R a+rX "$BACKUP_ROOT"

#-----------

CRON_LINE="0 1 * * * flock $LOCK_FILE $BACKUP_SCRIPT >> $LOG_FILE 2>&1"

(
    crontab -l 2>/dev/null || true
    echo "$CRON_LINE"
) | awk '!seen[$0]++' | crontab -

echo
echo "Created:"
echo "  $BACKUP_SCRIPT"
echo
echo "Cron:"
echo "  $CRON_LINE"
echo
echo "Permissions:"
echo "  $BACKUP_ROOT — чтение всем (a+rX), запись только root"