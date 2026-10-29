#!/bin/sh

clear

# поиск клиента
proc=$(ps -eo args= | awk '$1 ~ /(^|\/)(dhclient|dhcpcd)$/ {print; exit}')
nd_idx=""
nm_dev=""
[ -z "$proc" ] && nd_idx=$(ls -1 /run/systemd/netif/leases/ 2>/dev/null | head -1)
[ -z "$proc" ] && [ -z "$nd_idx" ] && \
  nm_dev=$(nmcli -t device show 2>/dev/null | awk -F: '/^GENERAL.DEVICE/{d=$2} /^DHCP4/{print d; exit}')

client=none; iface=""; server=""; dns=""; domain=""; renew=""; resolv=""

# path 1: dhclient/dhcpcd
if [ -n "$proc" ]; then
  client=$(echo "$proc" | awk '{print $1}'); client=${client##*/}
  iface=$(echo "$proc" | awk '{print $NF}')
  server=$(grep 'dhcp-server-identifier' /var/lib/dhcp/dhclient*.leases 2>/dev/null | tail -1 | sed 's/.*identifier //; s/;//')
  dns=$(grep 'option domain-name-servers' /var/lib/dhcp/dhclient*.leases 2>/dev/null | tail -1 | sed 's/.*servers //; s/;//')
  domain=$(grep 'option domain-name ' /var/lib/dhcp/dhclient*.leases 2>/dev/null | tail -1 | sed 's/.*domain-name //; s/[";]//g')
  renew=$(grep -E '^ *renew ' /var/lib/dhcp/dhclient*.leases 2>/dev/null | tail -1 | sed -E 's/^ *renew [0-9] //; s/;//')
  if [ -e /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate ]; then
    resolv="protected (nodnsupdate hook)"
  else
    resolv="rewritten on renewal"
  fi

# path 2: systemd-networkd, lease-файл назван по ifindex
elif [ -n "$nd_idx" ]; then
  l=/run/systemd/netif/leases/$nd_idx
  client=systemd-networkd
  iface=$(ip -o link show | awk -F': ' -v i="$nd_idx" '$1==i{print $2; exit}')
  server=$(grep '^SERVER_ADDRESS=' "$l" 2>/dev/null | cut -d= -f2)
  dns=$(grep '^DNS=' "$l" 2>/dev/null | cut -d= -f2)
  domain=$(grep '^DOMAINNAME=' "$l" 2>/dev/null | cut -d= -f2)
  renew=$(grep -E '^(T1|LIFETIME)=' "$l" 2>/dev/null | paste -sd' ' -)

# path 3: NetworkManager
elif [ -n "$nm_dev" ]; then
  client=NetworkManager
  iface=$nm_dev
  o=$(nmcli -t device show "$nm_dev" 2>/dev/null)
  server=$(printf '%s\n' "$o" | sed -n 's/^DHCP4.OPTION.*dhcp_server_identifier = //p' | head -1)
  dns=$(printf '%s\n' "$o" | sed -n 's/^DHCP4.OPTION.*domain_name_servers = //p' | head -1)
  domain=$(printf '%s\n' "$o" | sed -n 's/^DHCP4.OPTION.*domain_name = //p' | head -1)
  e=$(printf '%s\n' "$o" | sed -n 's/^DHCP4.OPTION.*expiry = //p' | head -1)
  [ -n "$e" ] && renew=$(date -d "@$e" '+%Y/%m/%d %H:%M:%S')
fi

# итог
if [ "$client" = none ]; then
  echo "$(hostname): no DHCP client — static network config"
else
  echo "$(hostname): $client on $iface | dhcp-server=$server | dns=$dns | domain=$domain | renew=$renew${resolv:+ | resolv.conf=$resolv}"
fi
