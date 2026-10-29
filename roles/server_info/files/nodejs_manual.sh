#!/bin/sh

clear

[ "$(id -u)" -eq 0 ] || echo "WARN=запущено не от root — видны только процессы $(id -un)" >&2
echo "HOST=$(hostname)"

hostmnt=$(readlink /proc/1/ns/mnt 2>/dev/null)
cache=""
vers=""
stale=""

# обход процессов
for d in /proc/[0-9]*; do
  pid=${d#/proc/}
  exe=$(readlink "$d/exe" 2>/dev/null) || continue
  path=${exe% (deleted)}
  case "${path##*/}" in
    node|nodejs|node[0-9]*|node-[0-9]*|nodejs[0-9]*|nodejs-[0-9]*) ;;
    *) continue ;;
  esac

  # контекст процесса
  user=$(stat -c %U "$d" 2>/dev/null)
  mnt=$(readlink "$d/ns/mnt" 2>/dev/null)
  cg=$(cat "$d/cgroup" 2>/dev/null)
  unit=$(printf '%s\n' "$cg" | grep -oE '[^/]+\.service' | tail -1)
  cid=$(printf '%s\n' "$cg" | grep -oE '[0-9a-f]{64}' | head -1 | cut -c1-12)
  if [ -n "$hostmnt" ] && [ "$mnt" != "$hostmnt" ]; then
    where="container${cid:+:$cid}"
  else
    where=host
  fi
  script=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null | awk '{
    a = $1; sub(/.*\//, "", a)
    if (a !~ /^node/) { sub(/[[:space:]]+$/, ""); print "title:" substr($0, 1, 60); exit }
    for (i = 2; i <= NF; i++) {
      if ($i ~ /^(-e|-p|--eval|--print)$/) { print "(" $i ")"; exit }
      if ($i ~ /^(-r|--require|--import|--loader|--experimental-loader|-C|--conditions|--title|--env-file|--inspect-port)$/) { i++; continue }
      if ($i !~ /^-/) { print $i; exit }
    } }')

  # версия: одна проверка на бинарь
  key="$mnt|$exe"
  ver=$(printf '%s\n' "$cache" | awk -F'\t' -v k="$key" '$1 == k { print $2; exit }')
  if [ -z "$ver" ]; then
    ver=$(timeout 5 "$d/exe" --version 2>/dev/null | head -1)
    if [ -z "$ver" ] && [ "$where" != host ] && [ "$exe" = "$path" ]; then
      ver=$(timeout 5 chroot "$d/root" "$path" --version 2>/dev/null | head -1)
    fi
    case "$ver" in v[0-9]*) ;; *) ver="?" ;; esac
    cache="$cache$key	$ver
"
  fi

  vers="$vers$ver
"
  flag=""
  if [ "$exe" != "$path" ]; then
    flag=" STALE"
    stale="$stale $pid"
  fi
  echo "node.proc: pid=$pid user=${user:-?} ver=$ver where=$where unit=${unit:--} exe=$path script=${script:--}$flag"
done

# итоги
if [ -z "$vers" ]; then
  echo "NODEJS=none"
else
  echo "NODEJS=$(printf '%s' "$vers" | sed 's/^[[:space:]]*//' | grep . | sort | uniq -c | sort -rn | awk '{ printf "%s%sx%s", (NR > 1 ? " " : ""), $2, $1 }')"
fi
[ -n "$stale" ] && echo "STALE=pid${stale} (бинарь обновлён после старта — процесс работает на старой версии, нужен перезапуск)"

# node из PATH
p=$(command -v node 2>/dev/null || command -v nodejs 2>/dev/null)
if [ -n "$p" ]; then
  echo "INSTALLED=$p $(timeout 5 "$p" --version 2>/dev/null | head -1)"
else
  echo "INSTALLED=нет в PATH"
fi
