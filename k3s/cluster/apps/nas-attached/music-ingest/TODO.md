# TODO

## Before First Deploy
- Fill and encrypt `core/secret.sops.yaml`.
- Build and push the custom beets image from `image/`.
- Create the Keycloak client and callback URL for the ingest host.
- Reconcile `music-ingest` and verify oauth2-proxy, FileBrowser, and beets workloads.
- Add the edge route for the chosen ingest hostname/path.

## Ingest Pipeline Follow-Up
- Verify FileBrowser proxy-auth behavior behind oauth2-proxy.
- Verify beets state on `local-path` is stable and decide backup strategy for the PVC.
- Create the Unraid directories if missing:
  - `/mnt/user/uploads/music-ingest`
  - `/mnt/user/music/managed`
- Decide whether upload/review/rejected/logs directory creation should stay in `bootstrap.sh` or move to a one-time init job.
- Review CronJob schedules after first real ingest runs.
- Decide whether `chroma` and `replaygain` should remain enabled by default or be trimmed.

## Routing Consolidation
- Move Navidrome from `music.dege.app` to either `music.dege.app/listen` or keep it at `/` and mount other tools under subpaths.
- Move Picard from `tags.dege.app` to `music.dege.app/tags`.
- Decide whether ingest should live at `music.dege.app/ingest` or remain on its own host.
- Update edge/Caddy routing once the final path layout is chosen.
- Verify base-path behavior for Navidrome, Picard, and oauth2-proxy after path changes.

## Nice To Have
- Consider a dedicated backup workflow for the beets SQLite state.
- Consider path-based cleanup middleware or rate limiting for large uploads.
- Add operational runbooks for manual beets jobs and log replay.
