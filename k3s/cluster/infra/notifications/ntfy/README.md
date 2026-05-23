# ntfy

Self-hosted ntfy instance for homelab notifications.

## Important settings

- Public URL: `https://ntfy.dege.app`
- Auth default: `deny-all`
- Login enabled: `true`
- iOS support: `NTFY_UPSTREAM_BASE_URL=https://ntfy.sh`

## Secrets to fill

In `secret.sops.yaml`:

- `NTFY_AUTH_USERS`
  - replace the empty hashes with bcrypt hashes
- `NTFY_AUTH_ACCESS`
  - adjust topic ACLs if needed
- `NTFY_AUTH_TOKENS`
  - optional

Suggested users:
- `ntfy-admin`
- `alertmanager-publisher`
