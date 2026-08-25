#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Собирает бинарь для Gitea (bin/monitoring/alloy/alloy).
# Обновил версию здесь — обнови alloy_version в defaults/main.yml,
# иначе роль не увидит новый бинарь.

# env
ALLOY_VER="1.18.1"
BINARY_NAME="alloy"
ARCHIVE_NAME="alloy-linux-amd64.zip"
ARCHIVE_BINARY="alloy-linux-amd64"
DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/v${ALLOY_VER}/${ARCHIVE_NAME}"
SHA256="fac853cbc3983a50a2368f9a685b31f74392ae86dd6155461b11a911c07b483c"

# main
for cmd in curl unzip sha256sum mktemp mv chmod; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Нет команды '$cmd'" >&2
    exit 1
  }
done

if [[ -e "$BINARY_NAME" ]]; then
  echo "'./$BINARY_NAME' уже существует, перезаписывать не буду" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${SCRIPT_DIR}/.download.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT

echo "Скачиваем Alloy ${ALLOY_VER}..."
curl -fL --retry 3 -o "$TMP_DIR/$ARCHIVE_NAME" "$DOWNLOAD_URL"

[[ -s "$TMP_DIR/$ARCHIVE_NAME" ]] || { echo "Архив пустой" >&2; exit 1; }

echo "Проверяем SHA256..."
( cd "$TMP_DIR" && printf '%s  %s\n' "$SHA256" "$ARCHIVE_NAME" | sha256sum -c - )

echo "Распаковываем..."
unzip -q "$TMP_DIR/$ARCHIVE_NAME" -d "$TMP_DIR/extracted"

SOURCE_BINARY="$TMP_DIR/extracted/$ARCHIVE_BINARY"
[[ -f "$SOURCE_BINARY" ]] || { echo "В архиве нет бинаря $ARCHIVE_BINARY" >&2; exit 1; }

echo "Ставим бинарь..."
chmod +x "$SOURCE_BINARY"
mv -- "$SOURCE_BINARY" "$SCRIPT_DIR/$BINARY_NAME"

echo "Убираем временные файлы..."
rm -rf -- "$TMP_DIR"
trap - EXIT

echo "Готово"
echo "Выложить в Gitea: bin/monitoring/alloy/$BINARY_NAME"
