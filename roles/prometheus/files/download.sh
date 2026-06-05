#!/usr/bin/env bash
set -e

# env
PROM_VER="3.12.0"

# main
ARCHIVE="prometheus-${PROM_VER}.linux-amd64.tar.gz"
URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/${ARCHIVE}"

echo "Скачиваем Prometheus ${PROM_VER}..."
wget "$URL"

echo "Распаковываем..."
tar -xzf "$ARCHIVE"

echo "Удаляем архив..."
rm -f "$ARCHIVE"

echo "Готово"