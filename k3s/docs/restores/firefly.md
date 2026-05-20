# Firefly Restore Playbook

Firefly recovery is driven by the MariaDB dump.

## Artifact location

- `/mnt/user/backups/k3s/apps/firefly/database/mariadb`

## In-place restore

1. Scale Firefly down.

```bash
kubectl scale deployment/firefly -n firefly --replicas=0
```

2. Copy the selected dump into the MariaDB pod.

```bash
kubectl cp <PATH-TO-DUMP> firefly/mariadb-0:/tmp/firefly.sql.gz
```

3. Restore the database. Substitute the current DB user and password from the Firefly config and secret.

```bash
kubectl exec -it -n firefly mariadb-0 -- sh -lc '
gzip -dc /tmp/firefly.sql.gz | MYSQL_PWD=<DB_PASSWORD> mariadb -u <DB_USER> firefly
'
```

If you need a clean replacement rather than an overlay import, drop and recreate the `firefly` schema first.

4. Start Firefly again.

```bash
kubectl scale deployment/firefly -n firefly --replicas=1
kubectl rollout status deployment/firefly -n firefly
```

## Validation

Verify:

- the Firefly UI loads
- accounts, transactions, and rules are present
- scheduled jobs continue without schema errors
