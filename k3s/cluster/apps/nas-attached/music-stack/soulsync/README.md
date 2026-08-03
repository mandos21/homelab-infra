# SoulSync

SoulSync and slskd are deployed as single-replica NAS-attached music automation
services in the `soulsync` namespace. They are internal-only ClusterIP services;
there is currently no ingress or public route.

## Storage

- `/app/config`, `/app/logs`, and `/app/data` use VM-local retained PVCs.
- `/app/downloads` uses `/mnt/user/downloads`.
- `/app/Transfer` uses the managed music library at `/mnt/user/music/managed`.
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

## Upstream

- https://github.com/Nezreka/SoulSync
- https://raw.githubusercontent.com/Nezreka/SoulSync/main/docker-compose.yml
