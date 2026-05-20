# Restore Playbooks

These playbooks are the current restore procedures for the validated backup flows in this repo.

Use the smallest restore scope that solves the problem.

Order of preference:

1. application-consistent restore
2. Longhorn volume restore
3. etcd restore

Playbooks:

- `etcd.md`
- `longhorn.md`
- `mattermost.md`
- `keycloak.md`
- `nextcloud.md`
- `firefly.md`
- `bookstack.md`
- `home-assistant.md`

## General rules

- Restore into a disposable path first when practical.
- Do not overwrite live state until the artifact has been inspected.
- For DB-backed apps, stop or scale down the application before replacing the live database.
- For Nextcloud, keep the database, `/config`, and Unraid-side data snapshots aligned to the same maintenance window.
- After every restore, verify the application from both Kubernetes and the user-facing entrypoint.
