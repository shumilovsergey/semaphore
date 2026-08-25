#!/usr/bin/env bash
set -euo pipefail

# Собирает два артефакта для Gitea (bin/monitoring/grafana/):
#   grafana                    — бинарь
#   grafana-homepath.tar.gz    — public/ и conf/defaults.ini
#
# Бинарь без homepath не стартует, поэтому артефакта два.
# Роль распаковывает архив прямо в grafana_path (/opt/grafana).
#
# Обновил версию здесь — обнови grafana_version в defaults/main.yml,
# иначе роль не увидит новые артефакты.

# env
GRAFANA_VER="13.1.3"
ARCHIVE_NAME="grafana_${GRAFANA_VER}_31135815010_linux_amd64.tar.gz"
DOWNLOAD_URL="https://dl.grafana.com/grafana/release/${GRAFANA_VER}/${ARCHIVE_NAME}"
SHA256="e0fd22aa63901ebc961ee64195da60eef8624a831683ca10b26c7b068082e92b"

BINARY_OUT="grafana"
HOMEPATH_OUT="grafana-homepath.tar.gz"

# main
for cmd in curl tar sha256sum find; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Нет команды '$cmd'" >&2
    exit 1
  }
done

for path in "$BINARY_OUT" "$HOMEPATH_OUT"; do
  if [[ -e "$path" ]]; then
    echo "'./$path' уже существует, перезаписывать не буду" >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d "./.grafana-download.XXXXXX")"
cleanup() { rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT

EXTRACT_DIR="$TMP_DIR/extracted"
STAGE_DIR="$TMP_DIR/homepath"
mkdir -p "$EXTRACT_DIR" "$STAGE_DIR/conf"

echo "Скачиваем Grafana ${GRAFANA_VER}..."
curl -fL --retry 3 -o "$TMP_DIR/$ARCHIVE_NAME" "$DOWNLOAD_URL"

echo "Проверяем SHA256..."
printf '%s  %s\n' "$SHA256" "$TMP_DIR/$ARCHIVE_NAME" | sha256sum -c -

echo "Распаковываем..."
tar -xzf "$TMP_DIR/$ARCHIVE_NAME" -C "$EXTRACT_DIR"

GRAFANA_BIN="$(find "$EXTRACT_DIR" -type f -path '*/bin/grafana' -print -quit)"
PUBLIC_DIR="$(find "$EXTRACT_DIR" -type d -name public -print -quit)"
DEFAULTS_INI="$(find "$EXTRACT_DIR" -type f -path '*/conf/defaults.ini' -print -quit)"

[[ -n "$GRAFANA_BIN" ]]   || { echo "В архиве нет бинаря grafana" >&2; exit 1; }
[[ -n "$PUBLIC_DIR" ]]    || { echo "В архиве нет каталога public" >&2; exit 1; }
[[ -n "$DEFAULTS_INI" ]]  || { echo "В архиве нет conf/defaults.ini" >&2; exit 1; }

echo "Готовим бинарь..."
cp "$GRAFANA_BIN" "./$BINARY_OUT"
chmod +x "./$BINARY_OUT"

echo "Готовим homepath..."
cp -R "$PUBLIC_DIR" "$STAGE_DIR/public"
cp "$DEFAULTS_INI" "$STAGE_DIR/conf/defaults.ini"
tar -czf "./$HOMEPATH_OUT" -C "$STAGE_DIR" public conf

echo "Убираем временные файлы..."
cleanup
trap - EXIT

echo "Готово"
echo "Выложить в Gitea: bin/monitoring/grafana/{$BINARY_OUT,$HOMEPATH_OUT}"
