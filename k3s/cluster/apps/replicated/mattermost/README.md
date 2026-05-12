# Mattermost

This app includes:
- Postgres database
- Mattermost

Mattermost is exposed at:
- `theborocrew.com`
- `www.theborocrew.com`

## Migration Strategy

This migration uses a direct PostgreSQL data directory copy and direct NFS mounts for Mattermost file storage.

Why:
- keeps the running Mattermost image behavior close to the current Docker deployment
- avoids a logical dump/import cutover
- avoids copying Mattermost file storage at all

Requirements:
- the old Mattermost stack must be fully stopped before DB copy
- the PostgreSQL major version must remain `15`
- do not start the k8s Postgres instance until the DB copy is complete

## Storage Layout

The existing Mattermost NAS tree is mounted directly from:
- `/mnt/user/mattermost`

Subpaths used:
- `config` -> `/mattermost/config`
- `data` -> `/mattermost/data`
- `plugins` -> `/mattermost/plugins`
- `client/plugins` -> `/mattermost/client/plugins`
- `imports` -> `/mattermost/imports`

The Postgres PVC is cluster-local and receives a one-time copy from:
- `/mnt/user/appdata/mattermost_mm-postgres`

## Cutover Sequence

1. Reconcile the app while both workloads remain scaled to `0`.
2. Stop the old Docker Mattermost and Postgres containers.
3. Run the migration pod.
4. Copy the old Postgres data directory into `/target/pgdata`.
5. Scale Postgres to `1` and verify it starts.
6. Scale Mattermost to `1` and verify app startup.
7. Update edge Caddy config.

## Migration Pod

```bash
kubectl apply -f k3s/cluster/apps/replicated/mattermost/migration/pod-copy-postgres.yaml
kubectl wait --for=condition=Ready pod/mattermost-copy-postgres -n mattermost --timeout=180s
kubectl exec -it -n mattermost pod/mattermost-copy-postgres -- sh
```

Inside the pod:

```sh
id
ls -lah /source
ls -lah /target
mkdir -p /target/pgdata
rm -rf /target/pgdata/*
rm -rf /target/pgdata/.[!.]* /target/pgdata/..?* 2>/dev/null || true
tar -C /source -cf - . | tar -C /target/pgdata -xf -
```

Then:

```bash
kubectl delete pod mattermost-copy-postgres -n mattermost
```
