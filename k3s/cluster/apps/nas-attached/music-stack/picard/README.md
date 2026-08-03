# Picard

Picard is exposed at `https://picard.admin.dege.app` behind the shared admin
ForwardAuth middleware.

Current assumptions:
- config/state uses a VM-local PVC via `local-path`
- music library access remains NFS-backed from `/mnt/user/jfData/music`

This scaffold assumes path-based routing and therefore keeps the auth proxy and Picard ingress rules explicit.
