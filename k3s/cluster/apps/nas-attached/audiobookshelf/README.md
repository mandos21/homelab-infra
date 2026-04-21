# Audiobookshelf

Audiobookshelf is exposed at `audiobooks.dege.app`.

Storage split:
- app config uses a VM-local PVC via `local-path-retain`
- app metadata uses a separate VM-local PVC via `local-path-retain`
- audiobook media remains NFS-backed from `/mnt/user/audiobooks`

This keeps the mutable app state local to the cluster while leaving the large media library on the NAS.

## Migration

The current Audiobookshelf state lives in `/mnt/user/appdata/audiobookshelf`.

Migration targets:
- `/config` <= everything in appdata except the `metadata/` subdirectory
- `/metadata` <= the existing `metadata/` subdirectory

Recommended sequence:

```bash
kubectl scale deployment/audiobookshelf -n audiobookshelf --replicas=0
kubectl apply -f k3s/cluster/apps/nas-attached/audiobookshelf/migration/pod-copy-config.yaml
kubectl wait --for=condition=Ready pod/audiobookshelf-copy-config -n audiobookshelf --timeout=2m
kubectl exec -n audiobookshelf pod/audiobookshelf-copy-config -- sh -c 'cd /source && tar cpf - --exclude=./metadata . | tar xpf - -C /target-config'
kubectl exec -n audiobookshelf pod/audiobookshelf-copy-config -- sh -c 'cd /source/metadata && tar cpf - . | tar xpf - -C /target-metadata'
kubectl exec -n audiobookshelf pod/audiobookshelf-copy-config -- sh -c 'chown -R 99:100 /target-config /target-metadata'
kubectl delete pod/audiobookshelf-copy-config -n audiobookshelf
kubectl scale deployment/audiobookshelf -n audiobookshelf --replicas=1
kubectl rollout status deployment/audiobookshelf -n audiobookshelf
```

The important configuration is stored in Audiobookshelf's app state and database under these mounted directories, so migrating them before first use is the critical step.
