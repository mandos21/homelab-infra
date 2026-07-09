# Keycloak

This app includes:
- Postgres database
- Keycloak

Keycloak is exposed at `id.dege.app`.

## Migration

Use a SQL dump restore rather than a raw PostgreSQL data directory copy.

Create the migration pod:

```bash
kubectl apply -f k3s/cluster/apps/longhorn-backed/keycloak/migration/pod-copy-db.yaml
kubectl wait --for=condition=Ready pod/keycloak-copy-db -n keycloak --timeout=180s
kubectl exec -it -n keycloak pod/keycloak-copy-db -- sh
```

Inside the pod:

```sh
ls -lah /source
```

Pick the dump file you want, then restore it after resetting the database:

```sh
DUMP=/source/keycloak_YYYY-MM-DD_HH-MM.sql
psql -h postgres -U keycloak -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='keycloak' and pid <> pg_backend_pid();"
psql -h postgres -U keycloak -d postgres -c "drop database if exists keycloak;"
psql -h postgres -U keycloak -d postgres -c "create database keycloak owner keycloak;"
psql -h postgres -U keycloak -d keycloak < "$DUMP"
```

Then remove the migration pod:

```bash
kubectl delete pod keycloak-copy-db -n keycloak
```
