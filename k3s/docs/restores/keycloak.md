# Keycloak Restore Playbook

The Keycloak restore path is the PostgreSQL dump.

## Artifact location

- `/mnt/user/backups/k3s/apps/keycloak/database/postgres`

## In-place restore

1. Pick the dump file you want.
2. Scale Keycloak down.

```bash
kubectl scale deployment/keycloak -n keycloak --replicas=0
```

3. Copy the selected dump into the PostgreSQL pod.

```bash
kubectl cp <PATH-TO-DUMP> keycloak/postgres-0:/tmp/keycloak.dump
```

4. Restore the database. Substitute the current DB user and password from the Keycloak config and secret.

```bash
kubectl exec -it -n keycloak postgres-0 -- sh -lc '
export PGPASSWORD=<POSTGRES_PASSWORD>
dropdb --if-exists -U <POSTGRES_USER> keycloak
createdb -U <POSTGRES_USER> keycloak
pg_restore --clean --if-exists --no-owner --no-privileges -U <POSTGRES_USER> -d keycloak /tmp/keycloak.dump
'
```

5. Start Keycloak again.

```bash
kubectl scale deployment/keycloak -n keycloak --replicas=1
kubectl rollout status deployment/keycloak -n keycloak
```

## Notes

- Realm export is not the primary restore mechanism in this environment.
- The PostgreSQL dump is authoritative.

## Validation

```bash
kubectl get pods -n keycloak
kubectl logs -n keycloak deploy/keycloak --tail=200
```

Then verify:

- the Keycloak admin UI loads
- the expected realm(s) exist
- client logins and OIDC discovery work again
