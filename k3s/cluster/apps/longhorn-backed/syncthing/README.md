# Syncthing

Syncthing is the always-on peer for the Logseq graph.

## Layout

- one PVC: `syncthing-data`
- mounted at `/var/syncthing`
- Logseq graph path: `/var/syncthing/Logseq`

## Runtime

- single replica
- `hostNetwork: true` so LAN peers can reach the node directly
- GUI stays on `127.0.0.1:8384`
- sync ports exposed on the node:
  - `22000/tcp`
  - `22000/udp`
  - `21027/udp`

## Storage

- `longhorn-retain`
- `10Gi`

Longhorn keeps the Syncthing state and local graph copy durable on the storage nodes.

## Backups

The nightly backup job tars the Logseq graph from the Syncthing pod into:

- `/mnt/user/backups/k3s/apps/syncthing/files/logseq`

That backup is separate from Longhorn volume replication and is meant to protect the content of the graph itself.

