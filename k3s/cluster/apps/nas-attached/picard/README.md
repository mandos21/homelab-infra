# Picard

Picard is being prepared for path-based exposure at `music.dege.app/tags`.

Current assumptions:
- config/state uses a VM-local PVC via `local-path`
- music library access remains NFS-backed from `/mnt/user/jfData/music`
- oauth2-proxy callback: `https://music.dege.app/tags/oauth2/callback`

This scaffold assumes path-based routing and therefore keeps the auth proxy and Picard ingress rules explicit.
