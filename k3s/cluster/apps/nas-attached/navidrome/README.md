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
