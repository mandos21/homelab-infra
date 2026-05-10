# Keycloak

This app includes:
- Postgres database
- Keycloak

Keycloak is exposed at `id.mdegenaro.com`.

## Migration

This migration only copies the Postgres data directory from the old Docker appdata path.

Create the migration pod:

```bash
kubectl apply -f k3s/cluster/apps/replicated/keycloak/migration/pod-copy-db.yaml
kubectl wait --for=condition=Ready pod/keycloak-copy-db -n keycloak --timeout=180s
kubectl exec -it -n keycloak pod/keycloak-copy-db -- sh
```

Inside the pod:

```sh
ls -lah /source
ls -lah /target

tar -C /source -cf - . | tar -C /target -xf -
```

Then remove the migration pod:

```bash
kubectl delete pod keycloak-copy-db -n keycloak
```
