#!/bin/sh

clear

# служба: not installed | service active | service inactive
fw() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "not installed"
    return
  fi
  systemctl is-active "$2" >/dev/null 2>&1 && echo "service active" || echo "service inactive"
}

# nftables: служба и след роли nft
nft_state() {
  s=$(fw nft nftables)
  if [ "$s" = "service inactive" ]; then
    if grep -qs 'Managed by Ansible (role: nft)' /etc/nftables.d/*.nft; then
      s="$s (найден ansible nft конфиг — он уже работает, служба включится после перезагрузки сервера)"
    else
      s="$s (следов ansible nft role нет)"
    fi
  fi
  echo "$s"
}

# ufw: флаг ufw status, правила в ядре, пользовательские правила
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
  if ! iptables -w -S ufw-user-input >/dev/null 2>&1; then
    echo "active в ufw status, но правил ufw в ядре нет"
    return
  fi
  n=$(ufw show added 2>/dev/null | grep -c '^ufw ')
  if [ "$n" -eq 0 ]; then
    d=$(ufw status verbose 2>/dev/null | sed -n 's/^Default: //p')
    echo "active, но правил нет — работает только политика по умолчанию: ${d:-?}"
  else
    echo active
  fi
}

# конфиги nftables
c=""
for f in /etc/nftables.conf /etc/nftables.d/*.nft; do
  [ -f "$f" ] || continue
  c=1
  echo "--- $f"
  cat "$f"
done
[ -n "$c" ] || echo "конфигов nftables нет"
echo

# правила ufw
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  echo "--- ufw status verbose"
  ufw status verbose 2>&1
  echo
fi

echo "=== firewall: $(hostname) ==="
echo "ufw:      $(ufw_state)"
echo "nftables: $(nft_state)"
echo "iptables: $(fw iptables iptables)"
