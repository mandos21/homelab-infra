# Nextcloud

Nextcloud is a `nas-attached` app because it mixes Unraid-backed media mounts with VM-local application state.

## Layout

- `foundation/`
  Namespace, static NFS PVs/PVCs, and VM-local PVCs.
- `workload/`
  Runtime layer for MariaDB, Redis, Nextcloud, and Traefik integration.
- `migration/`
  One-off helper pod for copying the old `/mnt/user/appdata/*` contents into the PVCs.

## Storage

This stack uses four volumes:

1. Nextcloud app config on VM-local storage
- PVC: `nextcloud-config`
- StorageClass: `local-path-retain`
- Mounted at `/config`

2. MariaDB app config/data on VM-local storage
- PVC: `nextcloud-mariadb`
- StorageClass: `local-path-retain`
- Mounted at `/config`

3. Primary user data on NFS
- Unraid path: `/mnt/user/nextData`
- Mounted at `/data`

4. Auxiliary ebooks share on NFS
- Unraid path: `/mnt/user/ebook_uploads`
- Mounted at `/ebook_uploads`

## Services

- `mariadb`
- `redis`
- `nextcloud`

## Host

- `cloud.dege.app`

## TLS / Reverse Proxy Notes

The LinuxServer Nextcloud image serves HTTPS on port `443` with a self-signed certificate by default.

This stack configures Traefik to:
- talk to the backend over `https`
- skip backend certificate verification using a namespaced `ServersTransport`

## Secrets

Fill and encrypt:

- `workload/secret.sops.yaml`

Expected keys:
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`

## Migration

The migration pod copies:
- `/mnt/user/appdata/nextcloud` -> `nextcloud-config`
- `/mnt/user/appdata/mariadb` -> `nextcloud-mariadb`

The NFS-backed `/data` and `/ebook_uploads` mounts are used in place and do not require copying.

Suggested sequence:

```bash
kubectl scale deployment/nextcloud -n nextcloud --replicas=0
kubectl scale deployment/redis -n nextcloud --replicas=0
kubectl scale statefulset/mariadb -n nextcloud --replicas=0

kubectl apply -f k3s/cluster/apps/nas-attached/nextcloud/migration/pod-copy-configs.yaml
kubectl wait --for=condition=Ready pod/nextcloud-copy-configs -n nextcloud --timeout=180s
kubectl exec -it -n nextcloud pod/nextcloud-copy-configs -- sh
```

Inside the pod:

```sh
tar -C /source-nextcloud -cf - . | tar -C /target-nextcloud -xf -
tar -C /source-mariadb -cf - . | tar -C /target-mariadb -xf -
chown -R 99:100 /target-nextcloud /target-mariadb
```

Then:

```bash
kubectl delete pod/nextcloud-copy-configs -n nextcloud
kubectl scale statefulset/mariadb -n nextcloud --replicas=1
kubectl scale deployment/redis -n nextcloud --replicas=1
kubectl scale deployment/nextcloud -n nextcloud --replicas=1
kubectl rollout status statefulset/mariadb -n nextcloud
kubectl rollout status deployment/redis -n nextcloud
kubectl rollout status deployment/nextcloud -n nextcloud
```
