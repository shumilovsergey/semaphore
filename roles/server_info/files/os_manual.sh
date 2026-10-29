#!/bin/sh

clear

. /etc/os-release 2>/dev/null
name=${NAME:-$(uname -s)}
ver=${VERSION_ID:-?}
case "$ID" in
  debian) name=Debian; [ -r /etc/debian_version ] && ver=$(cat /etc/debian_version) ;;
esac
echo "$(hostname): $name $ver ($(uname -m))"
