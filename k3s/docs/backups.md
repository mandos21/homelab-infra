# Backups

## Required decisions

- Longhorn backup target: NFS on Unraid or S3-compatible.
- DB logical backups for stateful apps (e.g., PostgreSQL, MariaDB).

## Longhorn

1. Choose target and credentials.
2. Configure Longhorn backup target and recurring jobs.
3. Store backup credentials as SOPS secrets.

## Database backups

- Use app-specific jobs or sidecars to run `pg_dump`/`mysqldump`.
- Store artifacts in the same backup target.

## Restore testing

- Schedule quarterly restore drills.
- Document RTO/RPO expectations.
