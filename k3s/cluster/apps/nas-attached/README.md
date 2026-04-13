# NAS-Attached Apps

Place workloads here that are coupled to Unraid-backed storage.

Scheduling defaults:
- `nodeSelector: { node-type: "vm" }`
- Use NFS-backed PVCs, static NFS PVs, or other NAS-oriented storage
- Intended for services such as Plex, media tools, and downloaders that are typically single-replica

Stateful safety defaults:
- PVCs and static PVs should be annotated with `kustomize.toolkit.fluxcd.io/prune: disabled`
- stateful namespaces should also carry the same annotation
- Flux Kustomizations that own stateful apps should use `deletionPolicy: Orphan`
- use retain-oriented StorageClasses for stateful PVCs:
  - `local-path-retain`
  - `longhorn-retain`
  - `longhorn-3replicas-retain`

Reason:
- this prevents a refactor or Kustomization ownership change from silently deleting persistent state
- dynamic `local-path` volumes are especially dangerous because deleting the PVC can delete the underlying PV data

Intentional deletion workflow:
- scale the workload down first
- delete the PVC only when you are certain the data is no longer needed
- because reclaim policy is `Retain`, the PV and backing storage should remain after PVC deletion
- explicitly inspect the released PV before deleting it
- only then remove the PV and backend data if you truly want destruction

This is deliberate. Deleting data should require more than one step.
