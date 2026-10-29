#!/bin/sh

clear

[ "$(id -u)" -eq 0 ] || echo "WARN=запущено не от root — часть данных недоступна" >&2

out=$(
# info | IPv6 - inspect kernel and interface state
(
echo "== state =="
echo "kernel=$(uname -r)"

# выключено на уровне загрузки
grep -qw 'ipv6.disable=1' /proc/cmdline && echo "cmdline=ipv6.disable=1"
grep -sHnE 'ipv6\.disable' /etc/default/grub /etc/default/grub.d/*.cfg /etc/kernel/cmdline | sed 's/^/boot.config: /'
grep -sHnE '(blacklist|install)[[:space:]]+ipv6|options[[:space:]]+ipv6' /etc/modprobe.d/*.conf | sed 's/^/modprobe: /'

if [ ! -d /proc/sys/net/ipv6 ]; then
  echo "IPV6=absent (нет /proc/sys/net/ipv6 — ядро без IPv6 или ipv6.disable=1)"
  exit 0
fi

# текущие значения sysctl
for k in all default lo; do
  echo "sysctl.$k.disable_ipv6=$(cat /proc/sys/net/ipv6/conf/$k/disable_ipv6)"
done
echo "sysctl.bindv6only=$(cat /proc/sys/net/ipv6/bindv6only)"
if [ -w /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
  echo "sysctl.writable=yes"
else
  echo "sysctl.writable=no"
  echo "RISK=sysctl-readonly (/proc/sys/net/ipv6 только для чтения — контейнер, sysctl отсюда не применить)"
fi

# где sysctl закреплён на диске
seen=" "
for f in /etc/sysctl.conf /etc/sysctl.d/*.conf /run/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf /lib/sysctl.d/*.conf; do
  [ -f "$f" ] || continue
  rp=$(readlink -f "$f")
  case "$seen" in *" $rp "*) continue ;; esac
  seen="$seen$rp "
  grep -nE '^[[:space:]]*[^#;].*(disable_ipv6|bindv6only|accept_ra|autoconf)' "$f" | sed "s|^|sysctl.file: $f:|"
done

# интерфейсы: включён / выключен
on=""; off=""; virt=0
for d in /proc/sys/net/ipv6/conf/*; do
  i=${d##*/}
  case "$i" in
    all|default) continue ;;
    veth*|cali*|lxc*|tap*|fwpr*|fwln*|fwbr*|br-*) virt=$((virt + 1)); continue ;;
  esac
  if [ "$(cat "$d/disable_ipv6")" = 1 ]; then off="$off $i"; else on="$on $i"; fi
done
echo "iface.enabled=${on# }"
echo "iface.disabled=${off# }"
[ "$virt" -gt 0 ] && echo "iface.virtual=$virt (veth/cali/lxc/tap/br-* — не перечислены)"

# адреса и маршрут
ip -6 addr show 2>/dev/null | awk '
  /^[0-9]+:/ { d = $2; sub(/:$/, "", d); sub(/@.*/, "", d) }
  /inet6/ && /scope global/ { print "addr.global=" $2 " dev " d (/dynamic/ ? " (dynamic)" : " (static)") }
  /inet6/ && /scope link/   { ll++ }
  END { print "addr.linklocal.count=" ll + 0 }'
g=$(ip -6 addr show scope global 2>/dev/null | grep -c 'inet6')
r=$(ip -6 route show default 2>/dev/null | head -1)
echo "GLOBAL=$g"
echo "ROUTE6=${r:-нет}"

# итог
if [ -z "$on" ]; then
  state="disabled (sysctl, все интерфейсы)"
elif [ "$on" = " lo" ]; then
  state="disabled (sysctl, кроме lo)"
elif [ -z "$off" ]; then
  if [ "$g" -gt 0 ]; then state="enabled, есть глобальные адреса"; else state="enabled, только link-local"; fi
else
  state="partial (включён на:$on)"
fi
echo "IPV6=$state"

# проба наружу
p="${ipv6_probe_host:-}"
if [ -n "$p" ]; then
  if ping -6 -c1 -W2 "$p" >/dev/null 2>&1 || ping6 -c1 -W2 "$p" >/dev/null 2>&1; then
    echo "PROBE=$p ok"
  else
    echo "PROBE=$p НЕТ ОТВЕТА"
  fi
fi
)

# info | IPv6 - inspect network configuration layers
(
echo "== netcfg =="
act() { systemctl is-active --quiet "$1" 2>/dev/null; }

# активные сетевые слои
m=""
act NetworkManager   && m="$m NetworkManager"
act systemd-networkd && m="$m systemd-networkd"
if act networking; then
  m="$m ifupdown"
elif grep -sE '^[[:space:]]*iface[[:space:]]' /etc/network/interfaces /etc/network/interfaces.d/* \
     | grep -qvE 'iface[[:space:]]+lo[[:space:]]'; then
  s=$(systemctl is-active networking 2>/dev/null)
  m="$m ifupdown(networking:${s:-no-systemd})"
fi
act wicked           && m="$m wicked"
ls /etc/netplan/*.yaml >/dev/null 2>&1 && m="$m netplan"
[ -f /etc/cloud/cloud.cfg ] && ! [ -f /etc/cloud/cloud-init.disabled ] && m="$m cloud-init"
echo "NETMGR=${m# }"

# netplan
for f in /etc/netplan/*.yaml; do
  [ -f "$f" ] || continue
  grep -nE 'dhcp6|accept-ra|link-local|ipv6|::' "$f" | sed "s|^|netcfg.netplan: $f:|"
done
grep -sqE 'dhcp6:[[:space:]]*(true|yes)|accept-ra:[[:space:]]*(true|yes)' /etc/netplan/*.yaml \
  && echo "RISK=netplan-ipv6 (netplan включает dhcp6/accept-ra — networkd поднимет IPv6 на линке)"

# cloud-init перегенерирует netplan
grep -sHnE 'network:[[:space:]]*\{?[[:space:]]*config:[[:space:]]*disabled' /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/*.cfg \
  | sed 's/^/netcfg.cloud-init: /'

# systemd-networkd
grep -sHnE '^[[:space:]]*(IPv6[A-Za-z]*|DHCP|LinkLocalAddressing|Address=[^#]*:)' \
  /etc/systemd/network/*.network /run/systemd/network/*.network | sed 's/^/netcfg.networkd: /'
if act systemd-networkd; then
  ml=$(networkctl list --no-legend 2>/dev/null | awk '$5 == "configured" { printf "%s ", $2 }')
  echo "netcfg.networkd.managed=${ml:-нет}"
  if [ -n "$ml" ] && ! grep -sqE '^[[:space:]]*LinkLocalAddressing=(no|ipv4|false)' \
       /etc/systemd/network/*.network /run/systemd/network/*.network; then
    echo "RISK=networkd-linklocal (networkd управляет: ${ml% } — без LinkLocalAddressing=no|ipv4 может вернуть disable_ipv6=0 при перенастройке линка; в netplan: link-local: [ ipv4 ])"
  fi
fi

# NetworkManager
if command -v nmcli >/dev/null 2>&1 && act NetworkManager; then
  nmcli -t -f NAME con show --active 2>/dev/null | while IFS= read -r c; do
    [ "$c" = lo ] && continue
    v=$(nmcli -g ipv6.method con show "$c" 2>/dev/null)
    echo "netcfg.nm[$c]=ipv6.method:${v:-?}"
    case "$v" in
      disabled|ignore) ;;
      *) echo "RISK=networkmanager-ipv6 ([$c] ipv6.method=$v — NM вернёт IPv6 поверх sysctl)" ;;
    esac
  done
fi

# ifupdown
grep -sHnE 'inet6|ipv6|accept_ra|autoconf' /etc/network/interfaces /etc/network/interfaces.d/* \
  | sed 's/^/netcfg.ifupdown: /'

# RHEL ifcfg
grep -sHnE '^(IPV6|NETWORKING_IPV6)' /etc/sysconfig/network /etc/sysconfig/network-scripts/ifcfg-* \
  | sed 's/^/netcfg.ifcfg: /'
)

# info | IPv6 - inspect IPv6 consumers
(
echo "== consumers =="

# слушающие сокеты
if command -v ss >/dev/null 2>&1; then
  l6=$(ss -lntup 2>/dev/null | awk 'NR > 1 {
    l = $5; h = l
    sub(/:[^:]*$/, "", h); gsub(/[][]/, "", h); sub(/%.*/, "", h)
    if (h == "*" || h == "::") c = "wild"
    else if (h == "::1")       c = "lo"
    else if (h ~ /^::ffff:/)   c = "mapped"
    else if (h ~ /:/)          c = "addr"
    else next
    p = "-"; if (match($7, /"[^"]+"/)) p = substr($7, RSTART + 1, RLENGTH - 2)
    print "listen6." c "=" $1 " " l " " p
  }' | sort -u)
else
  l6=$(netstat -lntup 2>/dev/null | awk '$1 ~ /6$/ { print "listen6.raw=" $0 }')
fi
[ -n "$l6" ] && echo "$l6"
w=$(printf '%s\n' "$l6" | grep -c '^listen6\.wild=')
lo=$(printf '%s\n' "$l6" | grep -c '^listen6\.lo=')
a=$(printf '%s\n' "$l6" | grep -c '^listen6\.addr=')
mp=$(printf '%s\n' "$l6" | grep -c '^listen6\.mapped=')
echo "LISTEN6=wild:$w lo:$lo addr:$a mapped:$mp"
[ "$lo" -gt 0 ] && echo "RISK=listen-loopback6 ($lo сокетов на ::1 — не стартуют, если выключить IPv6 и на lo)"
[ "$a" -gt 0 ]  && echo "RISK=listen-addr6 ($a сокетов на конкретных IPv6-адресах — не стартуют после выключения)"

# localhost в /etc/hosts
grep -qE '^[[:space:]]*::1[[:space:]].*localhost' /etc/hosts && echo "hosts.localhost6=::1 localhost есть в /etc/hosts"

# IPv6 в конфигах сервисов
hc=""
hard() { grep -vE '\[::\]|[[:space:]]:::[0-9]' | grep -c . ; }
x=$(grep -sHnE '^[[:space:]]*(ListenAddress|AddressFamily)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf)
[ -n "$x" ] && { echo "$x" | sed 's/^/conf.sshd: /'; echo "$x" | cut -d: -f3- | grep -qE ':.*:|inet6' && hc="$hc sshd"; }
if command -v nginx >/dev/null 2>&1 && nginx -t >/dev/null 2>&1; then
  x=$(nginx -T 2>/dev/null | awk '/^# configuration file / { f = $4; sub(/:$/, "", f) }
    /^[[:space:]]*listen[[:space:]]+\[/ { sub(/^[[:space:]]+/, ""); print f ": " $0 }')
else
  x=$(grep -sHnE '^[[:space:]]*listen[[:space:]]+\[' /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf /etc/nginx/sites-enabled/*)
fi
[ -n "$x" ] && { echo "$x" | head -20 | sed 's/^/conf.nginx: /'; n=$(echo "$x" | hard); [ "$n" -gt 0 ] && hc="$hc nginx($n)"; }
x=$(grep -rsHnE '^[[:space:]]*bind[[:space:]]+(\[|::|ipv6@)' /etc/haproxy)
[ -n "$x" ] && { echo "$x" | head -20 | sed 's/^/conf.haproxy: /'; n=$(echo "$x" | hard); [ "$n" -gt 0 ] && hc="$hc haproxy($n)"; }
x=$(grep -rsHnE '^[[:space:]]*Listen[[:space:]]+\[' /etc/apache2 /etc/httpd)
[ -n "$x" ] && { echo "$x" | head -20 | sed 's/^/conf.apache: /'; n=$(echo "$x" | hard); [ "$n" -gt 0 ] && hc="$hc apache($n)"; }
if command -v postconf >/dev/null 2>&1; then
  x=$(postconf -h inet_protocols 2>/dev/null)
  if [ -z "$x" ]; then
    echo "conf.postfix: postconf ничего не вернул — postfix не настроен"
  else
    echo "conf.postfix: inet_protocols=$x"
    [ "$x" = ipv4 ] || hc="$hc postfix($x)"
  fi
fi
[ -z "$hc" ] && hc=" нет"
echo "HARDCODED=${hc# }"
)

# info | IPv6 - inspect container platforms
(
echo "== platform =="
act() { systemctl is-active --quiet "$1" 2>/dev/null; }

# Docker
if command -v docker >/dev/null 2>&1; then
  grep -snE 'ipv6|ip6tables|fixed-cidr-v6' /etc/docker/daemon.json | sed 's/^/docker.daemon.json: /'
  grep -sqE '"ipv6"[[:space:]]*:[[:space:]]*true' /etc/docker/daemon.json \
    && echo "RISK=docker-ipv6-daemon (в daemon.json \"ipv6\": true)"
  if act docker; then
    n=$(docker ps -q 2>/dev/null | wc -l)
    nets=$(docker network ls -q 2>/dev/null | xargs -r docker network inspect -f '{{.Name}} ipv6={{.EnableIPv6}}' 2>/dev/null)
    echo "$nets" | sed '/^$/d; s/^/docker.network: /'
    v6=$(printf '%s\n' "$nets" | grep -c 'ipv6=true')
    echo "DOCKER=active, контейнеров запущено: $n, сетей с IPv6: $v6"
    [ "$v6" -gt 0 ] && echo "RISK=docker-ipv6-networks ($v6 сетей Docker с EnableIPv6)"
  else
    echo "DOCKER=установлен, служба не активна"
  fi
else
  echo "DOCKER=нет"
fi
command -v podman >/dev/null 2>&1 && echo "podman=установлен"

# Kubernetes
k=""
for u in kubelet k3s k3s-agent rke2-server rke2-agent snap.microk8s.daemon-kubelite; do
  act "$u" && k="$k $u"
done
[ -f /etc/kubernetes/kubelet.conf ] && k="$k kubeadm"
if [ -n "$k" ]; then
  echo "K8S=yes:$k"
  echo "RISK=k8s (на узле Kubernetes IPv6 и netfilter принадлежат CNI)"
  grep -sHnE 'cidr|node-ip|ipv6|dual' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml \
    /etc/kubernetes/manifests/kube-apiserver.yaml \
    /var/lib/kubelet/config.yaml /var/lib/kubelet/kubeadm-flags.env \
    /etc/rancher/k3s/config.yaml /etc/rancher/rke2/config.yaml \
    /var/snap/microk8s/current/args/kube-proxy \
    | head -30 | sed 's/^/k8s.config: /'
  grep -sHnE 'ipv6|::|"cidr"|subnet' /etc/cni/net.d/* | head -30 | sed 's/^/k8s.cni: /'
else
  echo "K8S=нет"
fi
)
)

# подробности
out=$(printf '%s\n' "$out" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep .)
printf '%s\n' "$out"

# итог
. /etc/os-release 2>/dev/null
name=${NAME:-$(uname -s)}
ver=${VERSION_ID:-?}
case "$ID" in
  debian) name=Debian; [ -r /etc/debian_version ] && ver=$(cat /etc/debian_version) ;;
esac
v=$(systemd-detect-virt 2>/dev/null)
echo
echo "=== $(hostname): $name $ver, virt=${v:-?} ==="
printf '%s\n' "$out" | grep -E '^(IPV6|GLOBAL|ROUTE6|PROBE|NETMGR|LISTEN6|HARDCODED|DOCKER|K8S|RISK)='
