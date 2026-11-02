#!/usr/bin/env python3
"""Create server YAML files and assign simple Ansible role names."""

import argparse
import io
import json
import subprocess
from pathlib import Path

from ruamel.yaml import YAML

ROOT = Path(__file__).resolve().parent.parent
INVENTORY = ROOT / "inventory" / "host.ini"
SERVERS = ROOT / "servers"


def get_inventory():
    result = subprocess.run(
        ["ansible-inventory", "-i", str(INVENTORY), "--list"],
        check=True,
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    return json.loads(result.stdout)


def get_hosts(inventory, group=None):
    if group is None:
        return sorted(inventory.get("_meta", {}).get("hostvars", {}))
    if group not in inventory:
        raise ValueError(f"Unknown inventory group: {group}")

    hosts = set()
    visited = set()

    def collect(name):
        if name in visited:
            return
        visited.add(name)
        data = inventory.get(name, {})
        hosts.update(data.get("hosts", []))
        for child in data.get("children", []):
            collect(child)

    collect(group)
    return sorted(hosts)


def init_hosts(hosts, dry_run=False):
    for host in hosts:
        path = SERVERS / f"{host}.yml"
        if path.exists():
            continue
        print(f"CREATE {path.relative_to(ROOT)}")
        if not dry_run:
            SERVERS.mkdir(parents=True, exist_ok=True)
            with path.open("x", encoding="utf-8") as f:
                f.write("---\n\n#---roles\nserver_roles: []\n\n#---vars\n")


def add_role(hosts, role, dry_run=False):
    yaml = YAML()
    yaml.preserve_quotes = True
    for host in hosts:
        path = SERVERS / f"{host}.yml"
        if not path.is_file():
            print(f"SKIP {path.name}: file missing")
            continue
        original = path.read_text(encoding="utf-8")
        data = yaml.load(original)
        if not isinstance(data, dict):
            print(f"SKIP {path.name}: expected YAML mapping")
            continue
        roles = data.get("server_roles")
        if roles is None:
            roles = []
            data["server_roles"] = roles
        if not isinstance(roles, list) or not all(isinstance(r, str) for r in roles):
            print(f"SKIP {path.name}: server_roles must be a list of strings")
            continue
        if role in roles:
            continue
        roles.append(role)
        print(f"ADD {role} -> {path.relative_to(ROOT)}")
        if not dry_run:
            output = io.StringIO()
            yaml.dump(data, output)
            path.write_text(output.getvalue(), encoding="utf-8")


def remove_role(hosts, role, dry_run=False):
    yaml = YAML()
    yaml.preserve_quotes = True
    for host in hosts:
        path = SERVERS / f"{host}.yml"
        if not path.is_file():
            print(f"SKIP {path.name}: file missing")
            continue
        original = path.read_text(encoding="utf-8")
        data = yaml.load(original)
        if not isinstance(data, dict):
            print(f"SKIP {path.name}: expected YAML mapping")
            continue
        roles = data.get("server_roles")
        if roles is None:
            continue
        if not isinstance(roles, list) or not all(isinstance(r, str) for r in roles):
            print(f"SKIP {path.name}: server_roles must be a list of strings")
            continue
        if role not in roles:
            continue
        while role in roles:
            roles.remove(role)
        print(f"REMOVE {role} -> {path.relative_to(ROOT)}")
        if not dry_run:
            output = io.StringIO()
            yaml.dump(data, output)
            path.write_text(output.getvalue(), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init", help="Create missing server YAML files")
    init.add_argument("--dry-run", action="store_true")
    for name, help_text in (
        ("add-role", "Assign role without duplicates"),
        ("remove-role", "Remove role where present"),
    ):
        cmd = commands.add_parser(name, help=help_text)
        cmd.add_argument("role")
        target = cmd.add_mutually_exclusive_group(required=True)
        target.add_argument("--all", action="store_true")
        target.add_argument("--group")
        cmd.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()
    inventory = get_inventory()
    if args.command == "init":
        init_hosts(get_hosts(inventory), args.dry_run)
    elif args.command == "add-role":
        add_role(get_hosts(inventory, args.group), args.role, args.dry_run)
    elif args.command == "remove-role":
        remove_role(get_hosts(inventory, args.group), args.role, args.dry_run)


if __name__ == "__main__":
    main()
