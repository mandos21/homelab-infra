# Backups and Restore

This document is the current backup source of truth for the k3s side of the homelab.

Everything listed here is implemented and validated unless a section explicitly says otherwise.

## Backup model

Recovery is split into four layers:

1. Control plane
   - k3s embedded-etcd snapshots to local disk and Garage
2. Storage layer
   - Longhorn snapshots and backups to Garage
3. Application-consistent backups
   - logical database dumps and app-native exports written to `/mnt/user/backups/k3s`
4. NAS-attached data
   - Unraid-side datasets and snapshots outside Longhorn

No single layer replaces the others.

## Current coverage

| Scope | Backup mechanism | Target | Validation status |
| --- | --- | --- | --- |
| k3s embedded etcd | scheduled `etcd-snapshot` + on-demand snapshot support | local snapshots + Garage bucket `homelab-etcd/cluster1` | validated |
| Longhorn volumes | recurring snapshots + recurring backups | Garage bucket `homelab-longhorn/cluster1` | validated, including restore |
| Mattermost database | nightly `pg_dump` custom-format dump | `/mnt/user/backups/k3s/apps/mattermost/database/postgres` | validated |
| Mattermost export | nightly `mmctl` export archive | `/mnt/user/backups/k3s/apps/mattermost/exports` | validated |
| Keycloak database | nightly `pg_dump` custom-format dump | `/mnt/user/backups/k3s/apps/keycloak/database/postgres` | validated |
| Nextcloud database | nightly MariaDB logical dump | `/mnt/user/backups/k3s/apps/nextcloud/database/mariadb` | validated |
| Nextcloud config | nightly `/config` archive during maintenance mode | `/mnt/user/backups/k3s/apps/nextcloud/files/config` | validated |
| Firefly database | nightly MariaDB logical dump | `/mnt/user/backups/k3s/apps/firefly/database/mariadb` | validated |
| BookStack database | nightly MariaDB logical dump | `/mnt/user/backups/k3s/apps/bookstack/database/mariadb` | validated |
| BookStack config | nightly `/config` archive | `/mnt/user/backups/k3s/apps/bookstack/files/config` | validated |
| Home Assistant | native Home Assistant backups | Garage-configured backup location, managed in the app | validated by app workflow |

## Critical non-app artifacts

Keep these backed up separately from Kubernetes workload data:

- `/var/lib/rancher/k3s/server/token`
- the SOPS age private key
- this Git repository
- Unraid-side backup configuration and Garage configuration

The etcd restore path depends on the original k3s server token. The repo secrets depend on the age private key.

## Storage locations

### Garage buckets

- `homelab-etcd`
  - prefix: `cluster1/`
- `homelab-longhorn`
  - prefix: `cluster1/`
- Home Assistant native backups also target Garage, but that configuration is managed inside Home Assistant rather than in Git.

### Filesystem backup root

In-cluster logical backups write to:

- NFS server: `192.168.1.231`
- exported path: `/mnt/user/backups`
- cluster backup root: `/mnt/user/backups/k3s`

Current layout:

- `/mnt/user/backups/k3s/apps/mattermost/database/postgres`
- `/mnt/user/backups/k3s/apps/mattermost/exports`
- `/mnt/user/backups/k3s/apps/keycloak/database/postgres`
- `/mnt/user/backups/k3s/apps/nextcloud/database/mariadb`
- `/mnt/user/backups/k3s/apps/nextcloud/files/config`
- `/mnt/user/backups/k3s/apps/nextcloud/metadata`
- `/mnt/user/backups/k3s/apps/firefly/database/mariadb`
- `/mnt/user/backups/k3s/apps/bookstack/database/mariadb`
- `/mnt/user/backups/k3s/apps/bookstack/files/config`

## Schedules and retention

### etcd

Managed by Ansible in `k3s/ansible/playbooks/k3s-etcd-s3-backups.yaml`.

- schedule: every 6 hours
- local retention: 7
- Garage retention: 14
- compression: enabled

### Longhorn

Defined in `k3s/cluster/infra/longhorn/recurring-jobs.yaml`.

- `volume-snapshot-hourly`
  - schedule: `0 * * * *`
  - retain: 24
- `volume-backup-nightly`
  - schedule: `0 3 * * *`
  - retain: 14
- `volume-backup-weekly`
  - schedule: `0 4 * * 0`
  - retain: 8
- `longhorn-system-backup-weekly`
  - schedule: `30 4 * * 0`
  - retain: 8

### App-consistent jobs

Defined under `k3s/cluster/infra/backups/`.

- `nextcloud-backup`
  - schedule: `00 3 * * *`
  - retains: 14 DB dumps, 14 config archives, 14 metadata markers
- `mattermost-pgdump`
  - schedule: `10 3 * * *`
  - retains: 14 dumps
- `mattermost-mmctl-export`
  - schedule: `25 3 * * *`
  - retains: 14 export archives
- `keycloak-pgdump`
  - schedule: `40 3 * * *`
  - retains: 14 dumps
- `firefly-dbdump`
  - schedule: `50 3 * * *`
  - retains: 14 dumps
- `bookstack-backup`
  - schedule: `55 3 * * *`
  - retains: 14 DB dumps and 14 config archives

## Application-specific notes

### Mattermost

Two restore-capable artifacts exist:

1. PostgreSQL custom-format dump
2. `mmctl` export ZIP

The PostgreSQL dump is the authoritative database restore path.
For a full application-level recovery that includes exported files and media, use either the `mmctl` export ZIP or the Longhorn restore path for the shared Mattermost volume.

### Keycloak

The PostgreSQL dump is the authoritative backup.

Realm export is intentionally not automated. Keycloak's own import/export docs explicitly say that import/export is not a primary backup mechanism for a running system.

### Nextcloud

The in-cluster job backs up:

- the MariaDB database
- the Nextcloud `/config` tree

It does **not** copy:

- `/mnt/user/nextData`
- `/mnt/user/ebook_uploads`

Those datasets must be protected by Unraid-side snapshots or replication during the same maintenance window.

### Firefly

The durable state in this deployment is the MariaDB database. The DB dump is the primary restore artifact.

### BookStack

BookStack restore needs both:

- the MariaDB dump
- the `/config` archive

### Home Assistant

Home Assistant is intentionally backed up by its native backup system, with Longhorn remaining as a lower-level storage fallback.

## Routine checks

### etcd

```bash
sudo k3s etcd-snapshot ls
kubectl get etcdsnapshotfile
```

### Longhorn

```bash
kubectl -n longhorn-system get backuptargets.longhorn.io
kubectl -n longhorn-system get backups.longhorn.io
kubectl -n longhorn-system get recurringjobs.longhorn.io
```

### CronJobs

```bash
kubectl get cronjobs -n backups
kubectl get jobs -n backups --sort-by=.metadata.creationTimestamp
```

### Backup artifacts on disk

```bash
find /mnt/user/backups/k3s/apps -maxdepth 4 -type f | sort
```

## Remaining work outside this document

These items are intentionally outside the in-cluster backup framework:

- Unraid-side snapshot and replication policy for NAS-attached datasets
- offsite replication of `/mnt/user/backups/k3s`
- offsite replication strategy for Garage buckets

The most important NAS-attached dataset split is Nextcloud:

- in-cluster: DB + `/config`
- Unraid-side: `/mnt/user/nextData` and `/mnt/user/ebook_uploads`

## Restore playbooks

Restore procedures live in `k3s/docs/restores/`:

- `k3s/docs/restores/README.md`
- `k3s/docs/restores/etcd.md`
- `k3s/docs/restores/longhorn.md`
- `k3s/docs/restores/mattermost.md`
- `k3s/docs/restores/keycloak.md`
- `k3s/docs/restores/nextcloud.md`
- `k3s/docs/restores/firefly.md`
- `k3s/docs/restores/bookstack.md`
- `k3s/docs/restores/home-assistant.md`

Use those playbooks for actual recovery work rather than re-deriving commands under pressure.

## External references

- k3s etcd backup and restore: https://docs.k3s.io/datastore/backup-restore
- k3s etcd snapshot CLI: https://docs.k3s.io/cli/etcd-snapshot
- Keycloak import/export limitations: https://www.keycloak.org/server/importExport
- Mattermost export and import documentation: https://docs.mattermost.com/administration-guide/manage/mmctl-command-line-tool.html
- Home Assistant backup and restore: https://www.home-assistant.io/common-tasks/general/
