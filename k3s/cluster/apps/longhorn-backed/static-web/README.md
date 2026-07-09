# Static Web

Static Web is a small stateful service backed by Longhorn storage.

## Storage

- one PVC: `static-web-config`
- mounted at `/config`

## Hosts

- `mdegenaro.com`
- `www.mdegenaro.com`

## Migration

Create the migration pod:

```bash
kubectl apply -f k3s/cluster/apps/longhorn-backed/static-web/migration/pod-copy-config.yaml
kubectl wait --for=condition=Ready pod/static-web-copy-config -n static-web --timeout=180s
kubectl exec -it -n static-web pod/static-web-copy-config -- sh
```

Inside the pod:

```sh
tar -C /source -cf - . | tar -C /target -xf -
chown -R 99:100 /target
```
