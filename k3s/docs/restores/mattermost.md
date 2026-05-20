# Mattermost Restore Playbook

Mattermost has two validated restore artifacts:

1. PostgreSQL custom-format dump
2. `mmctl` export ZIP

Use the database dump when you need to replace the PostgreSQL state.
Use the `mmctl` export ZIP when you want the application-level import path, especially if you also need exported attachments and profile media independent of the live shared volume.

## Artifact locations

- PostgreSQL dumps:
  - `/mnt/user/backups/k3s/apps/mattermost/database/postgres`
- `mmctl` exports:
  - `/mnt/user/backups/k3s/apps/mattermost/exports`

## In-place restore from PostgreSQL dump

This restores the database. If the `mattermost-shared` PVC also needs recovery, restore that PVC from Longhorn or prefer the `mmctl` export import path.


1. Pick the dump file you want.
2. Scale Mattermost down.

```bash
kubectl scale deployment/mattermost -n mattermost --replicas=0
```

3. Copy the selected dump into the PostgreSQL pod.

```bash
kubectl cp <PATH-TO-DUMP> mattermost/postgres-0:/tmp/mattermost.dump
```

4. Restore the database. Substitute the current DB user and password from the Mattermost config and secret.

```bash
kubectl exec -it -n mattermost postgres-0 -- sh -lc '
export PGPASSWORD=<POSTGRES_PASSWORD>
dropdb --if-exists -U <POSTGRES_USER> mattermost
createdb -U <POSTGRES_USER> mattermost
pg_restore --clean --if-exists --no-owner --no-privileges -U <POSTGRES_USER> -d mattermost /tmp/mattermost.dump
'
```

5. Start Mattermost again.

```bash
kubectl scale deployment/mattermost -n mattermost --replicas=1
kubectl rollout status deployment/mattermost -n mattermost
```

## Restore from Mattermost export ZIP

This is the application-native import path.

1. Place the desired export ZIP somewhere the Mattermost pod can read it. The deployment already mounts `/backups`, so using `/mnt/user/backups/k3s/apps/mattermost/exports` is fine.
2. Scale Mattermost up if it is not already running.
3. Start the import in local mode with bypass-upload.

```bash
kubectl exec -it -n mattermost deploy/mattermost -- \
  /mattermost/bin/mmctl --local import process --bypass-upload /backups/k3s/apps/mattermost/exports/<EXPORT>.zip
```

4. Track progress.

```bash
kubectl exec -it -n mattermost deploy/mattermost -- /mattermost/bin/mmctl --local import job list --json
kubectl exec -it -n mattermost deploy/mattermost -- /mattermost/bin/mmctl --local import list available --json
```

## Validation

```bash
kubectl get pods -n mattermost
kubectl logs -n mattermost deploy/mattermost --tail=200
```

Then verify:

- the Mattermost UI loads
- teams, channels, users, and files are present
- the expected message history is visible
