# Media Stack

This namespace groups the remaining media movement and playback services that are tightly coupled operationally:
- `mediaops-ssh`
- `plex`
- `qbittorrentvpn`

This app is intentionally `nas-attached` and single-node.

Design choices:
- all three workloads are pinned to `nimgerianor`
- `plex` uses `hostNetwork: true` and `runtimeClassName: nvidia`
- `qbittorrentvpn` stays on the existing combined `binhex/arch-qbittorrentvpn` model for the first migration
- `mediaops-ssh` and `qbittorrentvpn` are exposed only on the LAN with fixed MetalLB IPs
- all workloads are scaffolded inert with `replicas: 0`
- direct Unraid shares mounted inside `nimgerianor` under `/srv/unraid/*` are used via `hostPath` instead of NFS PV/PVCs

Important assumptions to review before cutover:
- `mediaops-ssh` config is mounted locally on `nimgerianor` at `/srv/unraid/appdata/mediaops-ssh`
- `plex` config is mounted locally on `nimgerianor` at `/srv/unraid/appdata/Plex-Media-Server`
- `plex` media root is mounted locally on `nimgerianor` at `/srv/unraid/plexData`
- `qbittorrentvpn` config is mounted locally on `nimgerianor` at `/srv/unraid/appdata/binhex-qbittorrentvpn`
- `qbittorrentvpn` downloads root is mounted locally on `nimgerianor` at `/srv/unraid/downloads`

Internal service IPs:
- `qbittorrentvpn`: `192.168.1.7`
- `mediaops-ssh`: `192.168.1.8`

External route:
- `plex.mdegenaro.com` is intended to reverse proxy directly to `nimgerianor:32400`

Cutover recommendation:
1. Reconcile while all workloads remain at `0` replicas.
2. Verify every PV/PVC is `Bound`.
3. Stop the old Unraid/Docker services.
4. Scale up `qbittorrentvpn` first and verify VPN + WebUI + Privoxy.
5. Scale up `mediaops-ssh` and verify internal access paths.
6. Scale up `plex` last and verify the existing library/config state comes up cleanly.
