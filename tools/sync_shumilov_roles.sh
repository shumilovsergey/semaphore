#!/usr/bin/env bash
set -euo pipefail

PUBLIC_REPO="https://github.com/shumilovsergey/ansible.git"
TMP_DIR="/tmp/shumilov-public-ansible"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not inside a git repository"
    exit 1
}

TARGET_DIR="$REPO_ROOT/shumilov_roles"

rm -rf "$TMP_DIR"

git clone \
  --depth=1 \
  --filter=blob:none \
  --sparse \
  "$PUBLIC_REPO" \
  "$TMP_DIR"

cd "$TMP_DIR"
git sparse-checkout set roles

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

rsync -av \
  "$TMP_DIR/roles/" \
  "$TARGET_DIR/"

rm -rf "$TMP_DIR"

echo "shumilov_roles synced"