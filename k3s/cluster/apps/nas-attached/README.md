# NAS-Attached Apps

Place workloads here that are coupled to Unraid-backed storage.

Scheduling defaults:
- `nodeSelector: { node-type: "vm" }`
- Use NFS-backed PVCs, static NFS PVs, or other NAS-oriented storage
- Intended for services such as Plex, media tools, and downloaders that are typically single-replica
