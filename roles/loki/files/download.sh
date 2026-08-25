#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Собирает бинарь для Gitea (bin/monitoring/loki/loki).
# Обновил версию здесь — обнови loki_version в defaults/main.yml,
# иначе роль не увидит новый бинарь.

# env
LOKI_VER="3.7.6"
BINARY_NAME="loki"
ARCHIVE_NAME="loki-linux-amd64.zip"
DOWNLOAD_URL="https://github.com/grafana/loki/releases/download/v${LOKI_VER}/${ARCHIVE_NAME}"
CHECKSUM_URL="https://github.com/grafana/loki/releases/download/v${LOKI_VER}/SHA256SUMS"

# main
for cmd in curl unzip sha256sum awk mktemp mv chmod; do
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

echo "Скачиваем Loki ${LOKI_VER}..."
curl -fL --retry 3 -o "$TMP_DIR/$ARCHIVE_NAME" "$DOWNLOAD_URL"
curl -fL --retry 3 -o "$TMP_DIR/SHA256SUMS" "$CHECKSUM_URL"

[[ -s "$TMP_DIR/$ARCHIVE_NAME" ]] || { echo "Архив пустой" >&2; exit 1; }

echo "Проверяем SHA256..."
EXPECTED_SHA256="$(awk -v file="$ARCHIVE_NAME" '$2 == file { print $1; exit }' "$TMP_DIR/SHA256SUMS")"
[[ -n "$EXPECTED_SHA256" ]] || { echo "В SHA256SUMS нет строки для $ARCHIVE_NAME" >&2; exit 1; }
( cd "$TMP_DIR" && printf '%s  %s\n' "$EXPECTED_SHA256" "$ARCHIVE_NAME" | sha256sum -c - )

echo "Распаковываем..."
unzip -q "$TMP_DIR/$ARCHIVE_NAME" -d "$TMP_DIR/extracted"

SOURCE_BINARY="$TMP_DIR/extracted/loki-linux-amd64"
[[ -f "$SOURCE_BINARY" ]] || { echo "В архиве нет бинаря loki" >&2; exit 1; }

echo "Ставим бинарь..."
chmod +x "$SOURCE_BINARY"
mv -- "$SOURCE_BINARY" "$SCRIPT_DIR/$BINARY_NAME"

echo "Убираем временные файлы..."
rm -rf -- "$TMP_DIR"
trap - EXIT

echo "Готово"
echo "Выложить в Gitea: bin/monitoring/loki/$BINARY_NAME"
