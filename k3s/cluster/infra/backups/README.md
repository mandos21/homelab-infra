# Backups Infra

This directory contains in-cluster backup jobs and the shared backup target mount used by those jobs.

Structure:

- `namespace.yaml`
- `shared/`
  Shared backup infrastructure such as the NFS PV/PVC and reusable helper scripts.
- `<app>/`
  One directory per application containing that app's backup config, secrets, RBAC, CronJobs, and scripts.

Current scope:

- shared NFS mount of `/mnt/user/backups`
- validated app-consistent backup jobs for Mattermost, Keycloak, Nextcloud, Firefly, and BookStack
- Nextcloud coordinated maintenance-window backup
- Mattermost nightly PostgreSQL logical dumps
- Mattermost nightly export archives produced via the in-cluster `mmctl` binary running in local mode
- Keycloak nightly PostgreSQL logical dumps
- Firefly nightly MariaDB logical dumps
- BookStack nightly MariaDB dump plus `/config` archive

## Backup target

Jobs write to:

- NFS server: `192.168.1.231`
- path: `/mnt/user/backups`

Artifacts are stored under:

- `/mnt/user/backups/k3s/apps/mattermost/database/postgres`
- `/mnt/user/backups/k3s/apps/mattermost/exports`

Recommended top-level layout for future jobs:

- `/mnt/user/backups/k3s/apps/<app>/database/<engine-or-format>`
- `/mnt/user/backups/k3s/apps/<app>/exports`
- `/mnt/user/backups/k3s/apps/<app>/files`
- `/mnt/user/backups/k3s/apps/<app>/metadata`

That keeps cluster-managed logical backups separate from:

- `/mnt/user/backups/garage/...`
- any non-k3s backup content already living in `/mnt/user/backups`

## Secrets

Fill and encrypt the per-app secret files under `k3s/cluster/infra/backups/`.

Required values:

- `nextcloud/secret.sops.yaml`
  - `NEXTCLOUD_DB_PASSWORD`
- `mattermost/secret.sops.yaml`
  - `MATTERMOST_POSTGRES_PASSWORD`
- `keycloak/secret.sops.yaml`
  - `KEYCLOAK_POSTGRES_PASSWORD`
- `firefly/secret.sops.yaml`
  - `FIREFLY_DB_PASSWORD`
- `bookstack/secret.sops.yaml`
  - `BOOKSTACK_DB_ROOT_PASSWORD`

## Schedules

- `mattermost-pgdump`
  - `10 3 * * *`
- `mattermost-mmctl-export`
  - `25 3 * * *`
- `keycloak-pgdump`
  - `40 3 * * *`
- `firefly-dbdump`
  - `50 3 * * *`
- `bookstack-backup`
  - `55 3 * * *`
- `nextcloud-backup`
  - `00 3 * * *`

All jobs:

- write timestamped artifacts
- keep the most recent 14 artifacts of each type
- write a simple metadata sidecar per artifact

## Mattermost implementation notes

- The PostgreSQL dump job runs directly from a `postgres` image.
- The export job does not store a Mattermost API token.
- Instead, it `kubectl exec`s into the running Mattermost pod and invokes `/mattermost/bin/mmctl --local ...`.
- The Mattermost deployment mounts the shared backup path directly as an inline NFS volume at `/backups`.
- The dedicated PV/PVC pair exists only in the `backups` namespace for CronJobs. App workloads should not get their own backup PV/PVC unless there is a strong reason.

## Mattermost restore notes

Primary restore artifacts:

1. `pg_dump` custom-format dump
2. Mattermost export ZIP

The database dump is the authoritative database restore path.
For full application-level recovery of exported content, use the Mattermost export archive or the Longhorn restore path for the shared Mattermost volume.

## Keycloak restore notes

Primary restore artifact:

1. `pg_dump` custom-format dump

The PostgreSQL dump is the authoritative restore path for Keycloak.
Realm export remains optional and should be treated as a convenience export, not a primary backup mechanism.

## Nextcloud restore notes

Primary restore artifacts:

1. MariaDB logical dump
2. Nextcloud config archive from `/config`
3. Unraid-side snapshots of:
   - `/mnt/user/nextData`
   - `/mnt/user/ebook_uploads`

The in-cluster CronJob does not duplicate `/data` or `/ebook_uploads`.
Instead, it puts Nextcloud into maintenance mode, captures the database and config, and writes a metadata marker that the Unraid-side data snapshot should be taken during the same maintenance window.
The Nextcloud backup job uses the application database user credentials, not MariaDB root.

## Firefly restore notes

Primary restore artifact:

1. MariaDB logical dump

Firefly in this cluster does not have a separate persistent app-data volume.
The MariaDB dump is the primary restore artifact.

## BookStack restore notes

Primary restore artifacts:

1. MariaDB logical dump
2. `/config` archive

BookStack stores persistent application data under `/config`.
This workflow captures both the MariaDB database and the app config/storage volume.
