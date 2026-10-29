#!/bin/sh

clear

# состояние: not installed | active | inactive
fw() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "not installed"
  elif systemctl is-active "$2" >/dev/null 2>&1; then
    echo active
  else
    echo inactive
  fi
}

echo "=== firewall: $(hostname) ==="
echo "ufw:      $(fw ufw ufw)"
echo "nftables: $(fw nft nftables)"
echo "iptables: $(fw iptables iptables)"
