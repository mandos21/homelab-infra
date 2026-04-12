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

Reason:
- this prevents a refactor or Kustomization ownership change from silently deleting persistent state
- dynamic `local-path` volumes are especially dangerous because deleting the PVC can delete the underlying PV data
