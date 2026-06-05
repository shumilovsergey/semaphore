#!/usr/bin/env bash
set -euo pipefail

PUBLIC_REPO="https://github.com/shumilovsergey/semaphore.git"
TMP_DIR="/tmp/shumilov-public-ansible"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not inside a git repository"
    exit 1
}

TARGET_DIR="$REPO_ROOT/shumilov_roles"

rm -rf "$TMP_DIR"

git clone --depth=1 "$PUBLIC_REPO" "$TMP_DIR"

if [ ! -d "$TMP_DIR/roles" ]; then
    echo "Error: no roles/ directory found in $PUBLIC_REPO"
    rm -rf "$TMP_DIR"
    exit 1
fi

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

rsync -av "$TMP_DIR/roles/" "$TARGET_DIR/"

rm -rf "$TMP_DIR"

echo "shumilov_roles synced"