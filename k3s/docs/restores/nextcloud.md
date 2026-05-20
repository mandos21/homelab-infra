# Nextcloud Restore Playbook

Nextcloud recovery requires three aligned artifacts:

1. MariaDB dump
2. `/config` archive
3. Unraid-side snapshots of `nextData` and `ebook_uploads`

Do not restore only the database and config while leaving the file data at a different point in time.

## Artifact locations

- database dumps:
  - `/mnt/user/backups/k3s/apps/nextcloud/database/mariadb`
- config archives:
  - `/mnt/user/backups/k3s/apps/nextcloud/files/config`
- maintenance markers:
  - `/mnt/user/backups/k3s/apps/nextcloud/metadata`
- Unraid-side datasets:
  - `/mnt/user/nextData`
  - `/mnt/user/ebook_uploads`

## Recovery order

1. choose one maintenance-window timestamp
2. restore the Unraid-side datasets to that timestamp
3. restore the MariaDB dump from that same window
4. restore the `/config` archive from that same window
5. bring the app back and run validation

## In-place restore

1. Scale the app down.

```bash
kubectl scale deployment/nextcloud -n nextcloud --replicas=0
```

2. Restore the Unraid-side datasets outside Kubernetes.
3. Copy the selected DB dump into the MariaDB pod.

```bash
kubectl cp <PATH-TO-DUMP> nextcloud/mariadb-0:/tmp/nextcloud.sql.gz
```

4. Restore the database. Substitute the current app DB user and password from the Nextcloud config.

```bash
kubectl exec -it -n nextcloud mariadb-0 -- sh -lc '
gzip -dc /tmp/nextcloud.sql.gz | MYSQL_PWD=<DB_PASSWORD> mariadb -u <DB_USER> nextcloud
'
```

If you need a clean replacement rather than an overlay import, drop and recreate the `nextcloud` schema first.

5. Restore the `/config` archive into the `nextcloud-config` PVC using a temporary helper pod that mounts the target PVC.
6. Start Nextcloud again.

```bash
kubectl scale deployment/nextcloud -n nextcloud --replicas=1
kubectl rollout status deployment/nextcloud -n nextcloud
```

## Post-restore consistency checks

If required, run the Nextcloud maintenance commands again after startup.

Examples:

```bash
kubectl exec -it -n nextcloud deploy/nextcloud -- /bin/sh -lc 'php /app/www/public/occ maintenance:mode --off'
kubectl exec -it -n nextcloud deploy/nextcloud -- /bin/sh -lc 'php /app/www/public/occ status'
```

## Validation

Verify:

- the web UI loads
- files are present
- user logins work
- background jobs resume
- there are no obvious DB/file mismatch errors in logs
