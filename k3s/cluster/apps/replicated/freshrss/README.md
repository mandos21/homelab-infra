# FreshRSS

FreshRSS is a small replicated app backed by Longhorn storage.

## Storage

- one PVC: `freshrss-data`
- mounted twice with subpaths:
  - `data` -> `/var/www/FreshRSS/data`
  - `extensions` -> `/var/www/FreshRSS/extensions`

This keeps the footprint simple while preserving the two logical directories from the Docker setup.

## Host

- `rss.dege.app`

## Secrets

Fill and encrypt:

- `workload/secret.sops.yaml`

## Migration

Create the migration pod:

```bash
kubectl apply -f k3s/cluster/apps/replicated/freshrss/migration/pod-copy-data.yaml
kubectl wait --for=condition=Ready pod/freshrss-copy-data -n freshrss --timeout=180s
kubectl exec -it -n freshrss pod/freshrss-copy-data -- sh
```

Inside the pod:

```sh
cp -a /source/data/. /target/data/
cp -a /source/extensions/. /target/extensions/
```

Then remove the pod and scale FreshRSS up if needed.
