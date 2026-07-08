# Idea: section headers / pseudo-comments in the env block

## Goal

Support "info lines" inside `app_config.env` so a large env dict can be grouped
into sections (e.g. auth, secrets). JSON has no comment syntax, so a `#`-prefixed
key doubles as a pseudo-comment in the Semaphore extra-vars JSON **and** as a
section header in the generated `.service` file.

Example env:

```json
"env": {
  "#AUTH": "section",
  "AUTH_URL": "...",
  "AUTH_INTERNAL": "...",
  "#SECRETS": "section",
  "APP_TOKEN": "...",
  "SECRET_KEY": "..."
}
```

## Why NOT the zero-code-change version

Putting `"#APP": "SECRETS"` with no template change just emits:

```
Environment=#APP=SECRETS
```

That is **not** a comment — systemd tries to set an env var literally named `#APP`.
Env var names must be `[A-Za-z_][A-Za-z0-9_]*`, so `#APP` is invalid: systemd
warns/drops it or injects junk into the app's process environment. Malformed, not clean.

## Chosen approach: tiny (~3-line) template change

In `templates/system.service.j2`, detect the `#` prefix and render a real systemd
comment (which systemd genuinely ignores):

```jinja
{% for key, value in app_config.env.items() %}
{% if key.startswith('#') %}

# {{ key[1:] }}: {{ value }}
{% else %}
Environment={{ key }}={{ value }}
{% endif %}
{% endfor %}
```

Result: `"#APP": "SECRETS"` -> clean `# APP: SECRETS` header, nothing injected
into the process.

## Notes

- **Order is safe**: Ansible's JSON loader and Jinja `.items()` both preserve
  insertion order, so top-to-bottom rendering holds.
- **Gotcha (separate issue)**: the "Deploy systemd service file" task runs
  `when: not service_file.stat.exists` — the `.service` file is written **only on
  first deploy**. On redeploy of an existing app, env changes (including these
  markers) won't appear until the service is recreated; the update path only does
  `systemctl restart`. If env edits should take effect on redeploy, revisit that
  `when` condition — separately from this idea.
