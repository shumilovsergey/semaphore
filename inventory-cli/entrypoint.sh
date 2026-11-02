#!/bin/sh
set -e
cat <<'HELP'

Inventory CLI
=============

# Создать недостающие YAML-файлы серверов
python inventory-cli/servers.py init --dry-run
python inventory-cli/servers.py init

# Добавить роль всем серверам или группе (без дубликатов)
python inventory-cli/servers.py add-role dns --all --dry-run
python inventory-cli/servers.py add-role dns --group prod --dry-run
python inventory-cli/servers.py add-role dns --group prod

# Удалить роль у всех серверов или группы
python inventory-cli/servers.py remove-role dns --all --dry-run
python inventory-cli/servers.py remove-role dns --group prod --dry-run
python inventory-cli/servers.py remove-role dns --group prod

# Выйти из контейнера
exit

HELP
exec /bin/bash -i
