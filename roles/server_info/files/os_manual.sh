#!/bin/sh

clear

[ ! -r /etc/os-release ] || . /etc/os-release
name=${NAME:-$(uname -s)}
ver=${VERSION_ID:-?}
case "${ID:-}" in
  debian) name=Debian; [ -r /etc/debian_version ] && ver=$(cat /etc/debian_version) ;;
esac

release=$(uname -r)
kernel_package=$(
  if command -v dpkg-query >/dev/null 2>&1; then
    for path in "/boot/vmlinuz-$release" "/lib/modules/$release" "/usr/lib/modules/$release"; do
      owner=$(dpkg-query -S "$path" 2>/dev/null | head -n 1 | cut -d: -f1)
      if [ -n "$owner" ]; then
        dpkg-query -W -f='${Package} ${Version}\n' "$owner" 2>/dev/null && exit 0
      fi
    done
  elif command -v rpm >/dev/null 2>&1; then
    for path in "/boot/vmlinuz-$release" "/lib/modules/$release" "/usr/lib/modules/$release"; do
      if owner=$(rpm -qf --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' "$path" 2>/dev/null); then
        printf '%s\n' "$owner"
        exit 0
      fi
    done
  fi
  printf '%s\n' 'не определён'
)

printf '%s: %s %s (%s); ядро: %s; пакет: %s\n' \
  "$(hostname)" "$name" "$ver" "$(uname -m)" "$release" "$kernel_package"
