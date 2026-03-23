# Backups

## Current target

- Longhorn backup target: `nfs://192.168.1.231:/mnt/user/longhorn-backups`

## How Longhorn uses it

- The backup target is cluster-wide.
- It is the destination store for Longhorn backups and restores.
- It does not decide which workloads get backed up or how often.
- Backup frequency is controlled separately by recurring jobs attached to a StorageClass, PVC, or Longhorn volume.

## Longhorn plan

1. Keep the cluster-wide NFS target configured in the Longhorn HelmRelease.
2. Add recurring jobs later for different workloads.
3. Use more frequent jobs for high-value apps such as Mattermost or Matrix.
4. Use less frequent jobs for lower-priority workloads.

## Database backups

- Longhorn backups protect the block volume, not application-level consistency by themselves.
- Stateful apps with databases should also get logical backups such as `pg_dump` or `mysqldump`.
- Store those artifacts in Unraid as well, either alongside Longhorn backups or in a separate app-backup path.

## Restore testing

- Schedule quarterly restore drills.
- Document node-failure recovery separately from full-cluster recovery.
- Document RTO/RPO expectations.
