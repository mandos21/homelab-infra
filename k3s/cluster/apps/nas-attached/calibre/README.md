# Calibre Web Automated

Calibre Web Automated is exposed at `ebooks.dege.app`.

Storage split:
- app state/config uses a VM-local PVC via `local-path-retain`
- calibre library remains NFS-backed from `/mnt/user/ebooks`
- upload/ingest directory remains NFS-backed from `/mnt/cache/ebook_uploads`

This mirrors the current Docker setup while moving the mutable app state into k3s-managed storage.

## Migration

The current Calibre Web Automated state lives in `/mnt/user/appdata/calibre-web-automated` and should be copied into the `calibre-config` PVC before first use.

Recommended sequence:

```bash
kubectl scale deployment/calibre-web-automated -n calibre --replicas=0
kubectl apply -f k3s/cluster/apps/nas-attached/calibre/migration/pod-copy-config.yaml
kubectl wait --for=condition=Ready pod/calibre-copy-config -n calibre --timeout=2m
kubectl exec -n calibre pod/calibre-copy-config -- sh -c 'cd /source && tar cpf - . | tar xpf - -C /target'
kubectl exec -n calibre pod/calibre-copy-config -- sh -c 'chown -R 99:100 /target'
kubectl delete pod/calibre-copy-config -n calibre
kubectl scale deployment/calibre-web-automated -n calibre --replicas=1
kubectl rollout status deployment/calibre-web-automated -n calibre
```

The application stores most of its configuration in its own DB inside `/config`, so copying the existing appdata is the important migration step.
