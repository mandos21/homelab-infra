# Vaultwarden

Vaultwarden is a small replicated service backed by Longhorn storage.

## Storage

- one PVC: `vaultwarden-data`
- mounted at `/data`

## Host

- `passwords.dege.app`

## Secrets

Fill and encrypt:

- `workload/secret.sops.yaml`

## Migration

Create the migration pod:

```bash
kubectl apply -f k3s/cluster/apps/replicated/vaultwarden/migration/pod-copy-data.yaml
kubectl wait --for=condition=Ready pod/vaultwarden-copy-data -n vaultwarden --timeout=180s
kubectl exec -it -n vaultwarden pod/vaultwarden-copy-data -- sh
```

Inside the pod:

```sh
tar -C /source -cf - . | tar -C /target -xf -
```

Then remove the migration pod and start Vaultwarden.
