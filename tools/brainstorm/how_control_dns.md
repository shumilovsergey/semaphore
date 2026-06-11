# How to control DNS centrally

## Core principle

> Declare what should be true. Verify reality matches before touching anything.

---

## Context

Infrastructure was managed manually — contains drift and misconfigs.
Goal: centralized DNS control that is easy to operate and safe to hand to anyone.

Known inventory (recon run, more servers may exist):

| server | manager | iface | dns servers | domain |
|---|---|---|---|---|
| vm-semaphore | resolv.conf | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-thanos | resolv.conf | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-thesis-elastic | resolv.conf | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-thesis-bak | resolv.conf | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-shumilov-temp | resolv.conf | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-metrics | systemd-resolved | ens18 | 10.2.11.22 10.2.11.242 | expoforum.ru |
| vm-astra-nfs-r7 | resolv.conf | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| astra-postgres-r7 | NetworkManager | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| astra-postgres-2-r7 | NetworkManager | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-astra-ds-r7 | NetworkManager | ens18 | 10.2.11.22 10.2.11.248 | expoforum.ru |
| vm-dev-thesis-web2 | systemd-resolved | ens18 | 10.2.11.22 10.2.11.242 | expoforum.ru |

**Open question:** is `10.2.11.242` (on vm-metrics, vm-dev-thesis-web2) intentional or drift?

---

## Chosen approach — accept the heterogeneity, control it safely

Rather than standardizing everyone to one manager (which requires risky manual prep on Astra servers
and doesn't buy much), we accept that the infra has 3 manager types and handle each cleanly.

**One task file per manager. The admin declares which manager a host uses. The role verifies
reality matches before writing a single byte.**

```
roles/dns/
  defaults/main.yml         ← dns_servers, dns_domain, dns_manager
  tasks/main.yml            ← validate vars → assert → apply
  tasks/assert_manager.yml  ← detect actual manager, fail if mismatch
  tasks/resolv_conf.yml     ← direct /etc/resolv.conf write
  tasks/systemd_resolved.yml ← drop-in /etc/systemd/resolved.conf.d/dns.conf
  tasks/networkmanager.yml  ← nmcli
  handlers/main.yml         ← restart handlers
```

### How it works

Admin sets vars in the server playbook:

```yaml
vars:
  dns_manager: "resolv_conf"       # resolv_conf | systemd_resolved | networkmanager
  dns_servers:
    - "10.2.11.22"
    - "10.2.11.248"
  dns_domain: "expoforum.ru"
```

Play execution order:
1. **Validate** — `dns_manager` is a known value, `dns_servers` is not empty → fail fast on typos
2. **Assert** — detect actual manager on the host, compare to declared → fail if mismatch
3. **Apply** — only runs if steps 1 and 2 passed

### Why declare instead of auto-detect

Auto-detection seems convenient but breaks down on real infra:

- On some Ubuntu setups both NetworkManager and systemd-resolved are active at the same time.
  Which one is actually managing DNS? Depends on NM config, not just service status.
- Astra Linux (Russian Debian) may have unusual daemon states after patch updates.
- Auto-detect hides drift — if a server's state changed, you want to know, not silently adapt.

Declaring the manager is intentional. The admin says "I know this server uses X."
The assert step catches it if that turns out to be wrong.

### Detection logic in assert_manager.yml

Priority order (matches reality for the current inventory):

1. `/etc/resolv.conf` is a symlink to a systemd path → `systemd_resolved`
2. NetworkManager is active → `networkmanager`
3. Otherwise → `resolv_conf`

This order matters: on systems where NM delegates to systemd-resolved, the symlink check
fires first and correctly identifies `systemd_resolved`.

---

## Risks to revisit as the infra grows

### 1. New manager types on new servers

The validation task allowlist is hardcoded: `resolv_conf | systemd_resolved | networkmanager`.
A new server with dnsmasq, openresolv, or any other setup will fail at step 1.

**That failure is correct** — it stops you from silently doing nothing or doing the wrong thing.
But you need to add a new task file and extend the allowlist before you can manage that server.

Watch for: new OS images (especially RedOS, AltLinux, or container-optimized distros)
that may ship with a different default DNS setup.

### 2. resolv_conf hosts — DHCP overwrite risk

For servers managed by `resolv_conf.yml`, the role writes `/etc/resolv.conf` directly.
If a DHCP client restarts (e.g., after a kernel update, network reconfiguration, or cloud
metadata refresh), it may overwrite the file and revert DNS.

Current state: acceptable for a stable on-prem network with static IPs.

If this becomes a problem: protect the file with `chattr +i` (immutable flag) after writing,
or configure the DHCP client to not manage DNS (`make_resolv_conf()` hook in dhclient).
Both options can be added to `resolv_conf.yml` when needed.

### 3. NetworkManager — multiple NICs

`networkmanager.yml` grabs the first active connection from `nmcli con show --active`.
On single-NIC servers this is fine. On servers with multiple interfaces (e.g., a separate
storage network or VLAN), the first connection might not be the primary one.

Watch for: any server that shows more than one active NM connection in recon output.
Fix when needed: add `nm_connection` as an optional host var to override the auto-select.

### 4. Detection blind spot — NM with systemd-resolved backend

On Ubuntu 22.04+ it is common for NetworkManager to delegate DNS to systemd-resolved.
In this state: NM is active, systemd-resolved is active, resolv.conf is a symlink.

The assert correctly identifies this as `systemd_resolved` (symlink check wins).
But if an admin sets `dns_manager: networkmanager` for such a host, the assert will fail —
which is the right outcome. The fix is to declare `systemd_resolved` and manage the drop-in.

The risk: if you ever need to stop using systemd-resolved on such a host, the migration
requires manual steps before the role can run again.

### 5. Astra Linux behavior is unverified

Astra servers (astra-postgres-*, vm-astra-ds-r7) use NetworkManager. Astra is a
Russian-patched Debian — the NM version and its DNS handling may differ from upstream.

Specifically unverified:
- Whether `nmcli con mod ipv4.ignore-auto-dns yes` behaves identically to upstream NM
- Whether NM on Astra respects the connection modification without a full restart

**Test on one Astra server before running the role across all astra-* hosts.**

### 6. Secondary DNS discrepancy

vm-metrics and vm-dev-thesis-web2 use `10.2.11.242` as secondary, everyone else uses `10.2.11.248`.
This is unresolved. If it is intentional (different resolver for that segment), keep it as a
per-host `dns_servers` override. If it is drift, standardize before the next role run.

---

## If the infra grows significantly

The current model (per-server playbook with inline vars) scales to maybe 20–30 servers
before it becomes hard to audit. At that point consider:

- **Ansible inventory with host_vars/** — move `dns_manager`, `dns_servers`, `dns_domain`
  into per-host var files. The role stays unchanged; only where vars live changes.
- **Group vars** — if clusters of servers always share the same DNS servers, define them
  once at group level and override per-host only where needed.
- **Separate recon playbook** — run `server_info/dns.yml` across all hosts first, generate
  a report, then run the dns role. Catches surprises before they become incidents.

None of this requires changing the role. The role is already structured for it.
