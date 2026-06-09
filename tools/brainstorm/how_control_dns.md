# How to control DNS centrally

## Core principle

> Better to work harder manually once and have clean simple playbooks,
> than to override complexity in playbooks forever.

---

## Context

Infrastructure was managed manually — likely contains misconfigs and drift.
Goal: centralized, easy-to-operate DNS control that can be handed to a manager as "this is under control."

First recon run (partial, more servers exist) showed:

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

**Open question:** is `10.2.11.242` (on vm-metrics, vm-dev-thesis-web2) intentional or drift vs the `10.2.11.248` everyone else uses?

---

## Options explored

### Option A — Massive role, handle all 3 managers
Write one role with three code paths: systemd-resolved, NetworkManager, resolv.conf.

- Pro: works as-is, no manual prep
- Con: complex forever, harder to maintain, testing surface is huge
- Verdict: rejected — complexity doesn't pay off

### Option B — Standardize to NetworkManager
Unify everyone onto NM. Works on Astra natively.

- Pro: Astra servers already use it
- Con: Ubuntu servers likely don't have NM installed, heavier daemon than needed
- Verdict: rejected — wrong direction for Ubuntu-based infra

### Option C — Write directly to /etc/resolv.conf, protect it
Simplest code. Use `chattr +i` or configure DHCP to not manage DNS.

- Pro: trivial role
- Con: on systemd-resolved servers resolv.conf is a symlink — can't write directly.
  Breaks the consistency goal.
- Verdict: rejected for mixed infra

### Option D — Standardize to systemd-resolved (chosen direction)
Pick one manager. systemd-resolved is the modern standard on Debian/Ubuntu.
Manual prep: migrate the NM and bare resolv.conf servers to use systemd-resolved before the control role runs.

- Pro: one code path in the control role forever, clean drop-in config pattern
- Con: manual prep needed on Astra (NM) servers — unknown risk since Astra is Russian-patched Debian
- Verdict: **best long-term fit**, user OK with manual prep

---

## Chosen direction

**Standardize all servers to systemd-resolved. Control DNS via drop-in config files.**

Why drop-in files (`/etc/systemd/resolved.conf.d/dns.conf`) instead of editing the main config:
- Idempotent and clean
- Survives package upgrades
- Easy to template in Ansible
- Easy to audit — one file per server, always the same place

Target state (after manual prep + role run):
```
DNS=10.2.11.22 10.2.11.248       # or 242 — to be decided
Domains=expoforum.ru
```

---

## Manual prep needed before control role

**For NetworkManager servers (astra-*):**
- Disable NM's DNS management: set `dns=none` in `/etc/NetworkManager/NetworkManager.conf`
- Enable and start `systemd-resolved`
- Point `/etc/resolv.conf` to the stub: `ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`
- Note: Astra Linux is Debian-based — systemd-resolved should be available, but test on one server first

**For bare resolv.conf servers (vm-*):**
- Same: enable systemd-resolved, symlink resolv.conf
- Verify no DHCP client is overwriting resolv.conf (check dhclient hooks)

---

## Control role design (concept)

Once all servers are on systemd-resolved:

```
roles/dns/
  defaults/main.yml     # dns_servers, dns_domain, dns_fallback_servers
  tasks/main.yml        # deploy drop-in, restart resolved, verify
  templates/dns.conf.j2 # the drop-in file
  handlers/main.yml     # restart systemd-resolved
```

Role is small. One template, one task, one handler.

---

## Open items

- [ ] Confirm target secondary DNS: 10.2.11.248 or 10.2.11.242?
- [ ] Run recon on full server list (not just the first batch)
- [ ] Test systemd-resolved enable on one Astra server before mass rollout
- [ ] Decide if vm-astra-nfs-r7 (resolv.conf, not NM) is actually Astra or Ubuntu
