#!/bin/sh

clear

# состояние: not installed | active | inactive
fw() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "not installed"
    return
  fi
  systemctl is-active "$2" >/dev/null 2>&1 && echo active || echo inactive
}

# ufw: флаг ufw status, затем правила в ядре
ufw_state() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "not installed"
    return
  fi
  st=$(ufw status 2>&1 | sed -n 's/^Status: //p')
  case "$st" in
    active) ;;
    inactive) echo inactive; return ;;
    *) echo "unknown (ufw status не ответил — нужен root)"; return ;;
  esac
  if iptables -w -S ufw-user-input >/dev/null 2>&1; then
    echo active
  else
    echo "active в ufw status, но правил ufw в ядре нет"
  fi
}

echo "=== firewall: $(hostname) ==="
echo "ufw:      $(ufw_state)"
echo "nftables: $(fw nft nftables)"
echo "iptables: $(fw iptables iptables)"
