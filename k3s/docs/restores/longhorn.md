# Longhorn Restore Playbook

Use this playbook for Longhorn volume backup recovery.

## Backups used

- Garage bucket `homelab-longhorn`, prefix `cluster1/`
- Longhorn recurring snapshots and recurring backups

## Default approach

Restore the backup into a **new** Longhorn volume first. Do not overwrite a live volume until the restored data has been inspected.

## Access the Longhorn UI

The UI is intentionally internal-only.

Use a port-forward when needed:

```bash
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
```

Then open `http://127.0.0.1:8080`.

## Restore a backup to a new Longhorn volume

1. Open the Longhorn UI.
2. Go to **Backup**.
3. Find the backup you want.
4. Restore it to a new volume name.
5. Wait until the restored volume is healthy.

## Inspect the restored volume

Create a temporary Kubernetes PV and PVC bound to the restored Longhorn volume, then mount it in a disposable pod.

Example PV:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: restore-test-<name>
spec:
  capacity:
    storage: <size>
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: longhorn
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeHandle: <restored-longhorn-volume-name>
```

Example PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restore-test-<name>
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: <size>
  storageClassName: longhorn
  volumeName: restore-test-<name>
```

Then mount that PVC in a disposable pod and inspect the files.

## Production use

If you need to recover a live workload from Longhorn rather than from an app-consistent dump:

1. scale the workload down
2. restore into a new volume
3. inspect the restored data
4. switch the workload to the restored storage only after inspection

This is a fallback path, not the preferred first-line restore for DB-backed apps.

## Validation

```bash
kubectl -n longhorn-system get backupvolumes.longhorn.io
kubectl -n longhorn-system get backups.longhorn.io
kubectl -n longhorn-system get volumes.longhorn.io
```

Confirm:

- the restored volume is healthy
- the mounted contents look correct
- the original live volume was not modified during inspection
