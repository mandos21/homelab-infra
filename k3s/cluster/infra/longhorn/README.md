# Longhorn Infra

This directory defines the Longhorn installation and cluster-wide backup scaffolding.

## What is configured here

- Longhorn Helm release
- Longhorn storage classes
- default backup target pointing at Garage
- S3 credential secret for the backup target
- recurring volume backup and snapshot jobs
- recurring Longhorn system backup job
- Longhorn settings related to recurring-job restore behavior

## Backup target

The cluster-wide backup target is:

```text
s3://homelab-longhorn@garage/cluster1/
```

The credential secret is:

```text
longhorn-backup-target
```

It must exist in the `longhorn-system` namespace and contain:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINTS`
- `AWS_REGION`

## Recurring jobs

Defined jobs:
- `volume-snapshot-hourly`
- `volume-backup-nightly`
- `volume-backup-weekly`
- `longhorn-system-backup-weekly`

The volume jobs are placed in the `default` recurring-job group so that volumes without explicit custom assignment still receive a baseline policy.

## Validate after reconcile

1. Confirm the backup target is healthy in the Longhorn UI.
2. Confirm the secret exists:

```bash
kubectl -n longhorn-system get secret longhorn-backup-target
```

3. Confirm recurring jobs exist:

```bash
kubectl -n longhorn-system get recurringjobs.longhorn.io
```

4. Run one manual backup of a small test volume.
5. Restore that backup to a new test volume and verify it.
