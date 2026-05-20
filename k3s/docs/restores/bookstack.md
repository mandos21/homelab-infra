# BookStack Restore Playbook

BookStack recovery needs both the MariaDB dump and the `/config` archive.

## Artifact locations

- database dumps:
  - `/mnt/user/backups/k3s/apps/bookstack/database/mariadb`
- config archives:
  - `/mnt/user/backups/k3s/apps/bookstack/files/config`

## In-place restore

1. Scale BookStack down.

```bash
kubectl scale deployment/bookstack -n bookstack --replicas=0
```

2. Copy the selected DB dump into the MariaDB pod.

```bash
kubectl cp <PATH-TO-DUMP> bookstack/mariadb-0:/tmp/bookstack.sql.gz
```

3. Restore the database. Substitute the current DB user and password from the BookStack config and secret.

```bash
kubectl exec -it -n bookstack mariadb-0 -- sh -lc '
gzip -dc /tmp/bookstack.sql.gz | MYSQL_PWD=<DB_PASSWORD> mariadb -u <DB_USER> bookstack
'
```

If you need a clean replacement rather than an overlay import, drop and recreate the `bookstack` schema first.

4. Restore the `/config` archive into the `bookstack-config` PVC using a temporary helper pod that mounts the target PVC.
5. Start BookStack again.

```bash
kubectl scale deployment/bookstack -n bookstack --replicas=1
kubectl rollout status deployment/bookstack -n bookstack
```

## Validation

Verify:

- the BookStack UI loads
- books, chapters, pages, and attachments are present
- image uploads and file storage are intact
