# SoulSync

SoulSync and slskd are deployed as single-replica NAS-attached music automation
services in the `soulsync` namespace. SoulSync remains on normal cluster
networking. slskd shares its Pod network namespace with Gluetun and uses a PIA
OpenVPN tunnel with VPN port forwarding.

## Storage

- `/app/config`, `/app/logs`, and `/app/data` use VM-local retained PVCs.
- `/app/downloads` and slskd `/downloads` use the completed-download tree at
  `/mnt/user/downloads/soulseek/complete`.
- slskd `/incomplete` uses `/mnt/user/downloads/soulseek/incomplete`, separate
  from the completed-download tree so cleanup cannot treat incomplete files as
  completed downloads.
- `/app/Transfer` uses the Navidrome music library at `/mnt/user/music/library`.
- `/app/Staging` shares the music-ingest staging area at `/mnt/user/uploads/music-ingest`.

The `/app/data` PVC is intentionally separate: upstream warns that mounting a
host directory there can overwrite the application modules.

## First-run setup

Open the UI and configure the download paths exactly as the container paths
above. slskd is available to SoulSync at
`http://slskd.soulsync.svc.cluster.local:5030`. Use a temporary port-forward to
configure the Soulseek account and create an API key, then enter that URL and
key in SoulSync's Settings → Downloads → Soulseek. Configure shared folders in
slskd as `/music` to avoid Soulseek bans.

Spotify is prepared through SoulSync's persisted Settings UI. The upstream
release documents entering the Spotify Client ID and Client Secret there, not
environment variables, so credentials are intentionally not placed in a Secret
the application would ignore. Use a temporary port-forward for the UI and its
OAuth callback port, then register the matching local redirect URI in Spotify's
developer dashboard. Callback ports 8888 and 8889 remain available internally.

## slskd VPN

The slskd Pod uses Gluetun with Private Internet Access/OpenVPN. The VPN
integration waits for Gluetun's control server and forwarded-port status before
allowing slskd to connect to Soulseek. The home-router port forward is not used
for this design; PIA supplies the public forwarded port.

Replace the sample values in `workload/secret.sops.yaml` with the Soulseek
credentials and the PIA credentials used by `media-stack-secrets`, then keep
the file SOPS-encrypted. slskd's own web authentication is disabled because
the admin Ingress is protected by the centralized Keycloak middleware.
Gluetun's control API is bound inside the shared Pod network namespace and is
intentionally not exposed as a Service.

## Upstream

- https://github.com/Nezreka/SoulSync
- https://raw.githubusercontent.com/Nezreka/SoulSync/main/docker-compose.yml
