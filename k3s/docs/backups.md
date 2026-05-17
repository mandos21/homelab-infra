# Backups and Restore

This document describes the current backup posture for the homelab and the restore procedures that are valid right now.

It is intentionally conservative. If a backup path is not implemented yet, this document says so directly.

## Current coverage

### Protected now

- K3s embedded-etcd control-plane state
  - local snapshots on each server
  - replicated snapshots in Garage bucket `homelab-etcd`, prefix `cluster1/`

### Not protected yet by the current K3s backup workflow

- Longhorn volume backups to Garage
- cluster-wide recurring Longhorn backup jobs
- most application-level logical backups
- NAS-attached data outside Longhorn-backed PVCs

## Backup layers

Think about recovery in layers:

1. Control-plane recovery
   - restore K3s etcd from snapshot
2. Volume recovery
   - restore Longhorn-backed PVC contents
3. Application-consistent recovery
   - restore logical dumps such as `pg_dump` or `mysqldump`
4. NAS / Unraid data recovery
   - restore external shares, media, and bind-mounted app data

Right now, only layer 1 is fully wired in this repo.

## Critical artifacts to protect

An etcd snapshot alone is not enough.

Keep these backed up securely:
- `/var/lib/rancher/k3s/server/token`
  - required to decrypt confidential bootstrap data in the snapshot
- SOPS age private key used for repo secrets
  - without it, encrypted secrets in Git are operationally difficult to recover
- this repo itself
  - especially `k3s/ansible/`, `k3s/cluster/`, and SOPS-encrypted vars

K3s backup and restore docs explicitly require the original server token when restoring to new hosts or when the token is not already present on disk:
- https://docs.k3s.io/datastore/backup-restore
- https://docs.k3s.io/cli/etcd-snapshot

## etcd backup configuration

The etcd backup configuration is managed by Ansible:
- playbook: [k3s/ansible/playbooks/k3s-etcd-s3-backups.yaml](/Users/mandos/dev/homelab-infra/k3s/ansible/playbooks/k3s-etcd-s3-backups.yaml)
- non-secret vars: [k3s/ansible/etcd-s3-backups.vars.yaml](/Users/mandos/dev/homelab-infra/k3s/ansible/etcd-s3-backups.vars.yaml)
- secret vars: [k3s/ansible/group_vars/secrets.sops.yaml](/Users/mandos/dev/homelab-infra/k3s/ansible/group_vars/secrets.sops.yaml)
- setup notes: [k3s/ansible/README-etcd-backups.md](/Users/mandos/dev/homelab-infra/k3s/ansible/README-etcd-backups.md)

Current intended settings:
- schedule: every 6 hours
- local retention: 7 snapshots
- remote retention in Garage: 14 snapshots
- compression: enabled
- S3 endpoint: Garage over HTTP on the internal LAN

### Routine checks

Check the installed drop-in on a server:

```bash
sudo cat /etc/rancher/k3s/config.yaml.d/50-etcd-s3-backups.yaml
```

List snapshots visible to the node:

```bash
sudo k3s etcd-snapshot ls
```

Take an on-demand snapshot:

```bash
sudo k3s etcd-snapshot save --name on-demand-test
```

Check cluster-visible snapshot objects:

```bash
kubectl get etcdsnapshotfile
```

Note: `k3s etcd-snapshot save` may warn about unrelated server flags such as `--disable` or `--etcd-snapshot-schedule-cron`. That is expected when the subcommand reads the full K3s config and ignores options that do not apply to the `save` command itself.

## etcd restore procedure

These procedures apply to the current three-server embedded-etcd cluster:
- `minandras`
- `tadandras`
- `nelandras`

Pick one server as the initial restore node. In practice, restore on `minandras` unless there is a reason not to.

### Before any restore

1. Confirm which snapshot you want.
2. Confirm you have the original server token.
3. Confirm whether you are restoring from:
   - Garage/S3, or
   - a local snapshot file on disk
4. Record the current failure state before changing anything:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

If the API is already down, record what you can from system logs on the servers instead.

### Snapshot selection

On a healthy or partially healthy server:

```bash
sudo k3s etcd-snapshot ls
```

If the cluster is still reachable, also check:

```bash
kubectl get etcdsnapshotfile
```

Garage-backed restores use the snapshot filename, not the full `s3://` URL.

### Restore to the existing hosts from Garage

Use this when the current control-plane nodes still exist and you want to restore the cluster state from the Garage copy of a snapshot.

1. Stop K3s on all server nodes:

```bash
sudo systemctl stop k3s
```

2. On the chosen restore node, run:

```bash
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=<SNAPSHOT-FILENAME>
```

Because the current K3s server config already contains the Garage S3 settings, K3s will attempt to download the snapshot from the configured bucket when only the filename is supplied.

3. Start K3s again on the restore node:

```bash
sudo systemctl start k3s
```

4. On the other server nodes, remove the old etcd data directory:

```bash
sudo rm -rf /var/lib/rancher/k3s/server/db/
```

5. Start K3s again on the peer servers so they rejoin the restored cluster:

```bash
sudo systemctl start k3s
```

This sequence follows the current K3s embedded-etcd restore procedure for multi-server clusters:
- https://docs.k3s.io/cli/etcd-snapshot

### Restore from a local snapshot file when S3 config is present

If you want to restore from a local file on disk, and the server config still includes S3 settings, explicitly disable S3 for the restore command:

```bash
sudo k3s server \
  --cluster-reset \
  --etcd-s3=false \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<SNAPSHOT-FILE>
```

Then continue with the same peer rejoin steps:
- start the restore node normally
- delete `/var/lib/rancher/k3s/server/db/` on peer servers
- start the peer servers normally

K3s documents this local-restore override explicitly when S3 backup configuration exists in the server config:
- https://docs.k3s.io/cli/etcd-snapshot

### Restore to replacement hosts

Use this when the original servers are gone or you are rebuilding the control plane onto new machines.

Requirements:
- the snapshot file
- the original server token from `/var/lib/rancher/k3s/server/token`
- equivalent K3s config for the replacement cluster

On the first replacement server:

```bash
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT> \
  --token=<BACKED-UP-TOKEN-VALUE>
```

Important caveats from K3s:
- if the K3s config file also contains a token, it must match the backed-up token
- restored snapshots include Kubernetes `Node` resources, so old node objects may need to be deleted manually after the cluster is back

Reference:
- https://docs.k3s.io/cli/etcd-snapshot

### Post-restore validation

After the restore:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get etcdsnapshotfile
```

Also check on each server:

```bash
sudo systemctl status k3s
sudo journalctl -u k3s -n 100 --no-pager
```

Things to confirm:
- all expected control-plane nodes rejoined
- core infra pods are healthy
- Flux resumes reconciliation
- Traefik and cert-manager recover
- application namespaces come back in expected order

## Recovery expectations

Current practical recovery scope:

- Best case:
  - restore control-plane state from Garage
  - restart workloads whose persistent data is still intact on Longhorn volumes or external storage
- Current limitation:
  - if a workload's persistent data is lost and it is not separately backed up at the application layer, etcd restore alone does not recover that data

That is the main reason Longhorn backup work is next.

## Longhorn backup status

Longhorn backup-to-Garage is not implemented yet in this repo.

Until that exists:
- Longhorn protects availability and replica placement
- Longhorn does not yet provide off-cluster backup/restore for PVC contents
- restore of deleted or corrupted PVC data depends on app-specific or external recovery paths

When Longhorn backup is added, document here:
- backup target configuration
- credential secret handling
- recurring job policy
- restore test workflow

## Application-level backups

Longhorn volume backups are not a substitute for logical database backups.

For database-backed apps, keep or add explicit restore docs under the app directory. Existing examples:
- [k3s/cluster/apps/replicated/keycloak/README.md](/Users/mandos/dev/homelab-infra/k3s/cluster/apps/replicated/keycloak/README.md)
- [stacks/moved-to-k3s/keycloak/README.md](/Users/mandos/dev/homelab-infra/stacks/moved-to-k3s/keycloak/README.md)

Use that pattern for future stateful services:
- identify the logical backup command
- document the backup destination
- document a tested restore path
- state whether the app also relies on Longhorn backup, NAS backup, or both

## NAS-attached workloads

NAS-attached workloads are a separate backup problem.

Examples:
- NFS-backed PVCs
- static PVs backed by Unraid shares
- media libraries
- application data kept outside Longhorn

These are not recovered by restoring k3s etcd.

Treat their backup source of truth as:
- the underlying Unraid/NAS backup workflow
- any app-specific export/dump procedure documented under the workload directory

## Review cadence

Revisit this document whenever any of these change:
- K3s snapshot schedule or retention
- Garage endpoint, bucket, or credential model
- Longhorn backup target
- app-level backup ownership
- node replacement or disaster-recovery procedure
