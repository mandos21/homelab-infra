# Navidrome

Navidrome is kept on the root of `music.dege.app` to avoid unnecessary client churn.

Current assumptions:
- app state uses a VM-local PVC via `local-path`
- music library remains NFS-backed from `/mnt/user/jfData/music`
- public host: `music.dege.app`

This split is intentional:
- SQLite / app state stays on local VM storage
- large media stays on NAS storage

If you later decide to move the library source to the beets-managed tree, update `core/pv-music.yaml`.

## Migration

To restore previously working Navidrome state into the current `navidrome-data` PVC, use the one-off pod in `migration/pod-copy-appdata.yaml`.

Recommended sequence:

```bash
kubectl scale deployment/navidrome -n navidrome --replicas=0
kubectl apply -f k3s/cluster/apps/nas-attached/navidrome/migration/pod-copy-appdata.yaml
kubectl wait --for=condition=Ready pod/navidrome-copy-appdata -n navidrome --timeout=2m
kubectl exec -n navidrome pod/navidrome-copy-appdata -- sh -c 'cd /source && tar cpf - . | tar xpf - -C /target'
kubectl exec -n navidrome pod/navidrome-copy-appdata -- sh -c 'chown -R 1000:1000 /target'
kubectl delete pod/navidrome-copy-appdata -n navidrome
kubectl scale deployment/navidrome -n navidrome --replicas=1
kubectl rollout status deployment/navidrome -n navidrome
```

If your previous appdata uses different ownership, adjust the `chown` step accordingly.
