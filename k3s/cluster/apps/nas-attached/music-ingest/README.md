# Music Ingest

Music ingest is a `nas-attached` service because it depends on Unraid-backed media shares and is intended to run on VM-class nodes.

## Host and Routing Notes

You asked about consolidating related services under one host:

- `music.dege.app` for Navidrome
- `music.dege.app/tags` for Picard
- `ingest.dege.app` for this ingest service

This is feasible, but not equally clean for every app.

- Navidrome is the easiest of the three because it supports a configurable base URL.
- Picard is workable behind a subpath, but desktop-webapp wrappers tend to be a little less pleasant than a root-host deployment.
- FileBrowser Quantum is now configured with native OIDC on its dedicated host instead of being fronted by oauth2-proxy.

Path consolidation is feasible in principle, but ingest is currently kept on its own host because FileBrowser does not behave cleanly behind the shared `music.dege.app` root path.

## Layout

- `foundation/`
  Namespace and storage primitives: static NFS PVs, their PVCs, and the local beets-state PVC.
- `workload/`
  Runtime layer for the service. Shared secret and Traefik middleware live here.
- `workload/filebrowser/`
  Upload UI manifests, including native OIDC configuration and the public Ingress.
- `workload/beets/`
  Single-replica admin runtime, scheduled import/maintenance jobs, suspended manual repair jobs, and the beets ConfigMap.
- `workload/postgres/`
  Internal PostgreSQL instance for future metadata enrichment data.
- `image/`
  Custom beets image scaffold built on the LSIO beets image.
- `migration/`
  One-off helper pods and manifests used during state or data migrations.

## Storage Model

This stack uses three storage classes of data:

1. Upload staging on NFS
- Unraid path: `/mnt/user/uploads/music-ingest`
- Mounted via static NFS PV/PVC
- Used for raw uploads, review queues, rejects, and ingest logs

2. Beets state on VM-local storage
- PVC: `beets-state`
- StorageClass: `local-path`
- Intended contents: `config.yaml`, SQLite library DB, plugin caches, and FileBrowser state subdirectories

3. Managed library output on NFS
- Unraid path: `/mnt/user/music/managed`
- Mounted via static NFS PV/PVC
- This is the final beets-owned library tree

4. Metadata enrichment database on VM-local storage
- PVC: `metadata-postgres`
- StorageClass: `local-path-retain`
- Intended use: future imported enrichment data derived from external SQLite dumps

## Metadata Enrichment Staging

If you need to import large SQLite-derived datasets that already live on `nimgerianor`, use:

- `migration/pod-metadata-import.yaml`

This pod:
- schedules directly to `nimgerianor`
- mounts a host directory at `/source`
- installs `sqlite3`, `zstd`, and `pv`
- exposes `psql` against the in-cluster `metadata-postgres` service

Before creating it, set the `hostPath` in `migration/pod-metadata-import.yaml` to the directory on `nimgerianor` that contains the decompressed `.sqlite3` files.

This pod is intentionally just a migration workstation. It does not assume an automatic SQLite-to-Postgres conversion strategy.

### Spotify SQLite Import

For the Spotify metadata datasets, the repo now includes:

- `migration/spotify-postgres/schema.sql`
- `migration/spotify-postgres/import-selected.sh`

These load the selected SQLite tables into one Postgres schema:

- `spotify_raw.album_images`
- `spotify_raw.albums`
- `spotify_raw.artist_albums`
- `spotify_raw.artist_images`
- `spotify_raw.artists`
- `spotify_raw.track_artists`
- `spotify_raw.tracks`
- `spotify_raw.track_audio_features`

Notes:
- this keeps the data in one Postgres database, under the `spotify_raw` schema
- `available_markets` and `artist_genres` are intentionally not imported right now
- the `available_markets_rowid` columns are preserved as raw IDs for now

Example from the host, after the `metadata-import` pod is running:

```bash
kubectl cp \
  k3s/cluster/apps/nas-attached/music-ingest/migration/spotify-postgres \
  music-ingest/metadata-import:/scratch/spotify-postgres

kubectl exec -it -n music-ingest pod/metadata-import -- bash -lc '
  chmod +x /scratch/spotify-postgres/import-selected.sh &&
  /scratch/spotify-postgres/import-selected.sh \
    /source/spotify_clean.sqlite3 \
    /source/spotify_clean_audio_features.sqlite3
'
```

## Why Beets State Is Not on NFS

Beets uses SQLite. SQLite works best on local disk. Putting the beets database on NFS would increase the chance of file-locking problems and subtle corruption issues. The better standard for this workload is:

- uploads on NFS
- final library on NFS
- SQLite-backed service state on local disk

That is what this version implements.

## Backup Implications

This change shifts beets state out of Unraid share backup conventions and onto node-local VM storage. That is the right technical tradeoff for SQLite, but it means you should explicitly decide how to back it up.

What should be backed up:
- the `beets-state` PVC contents
- the managed library on Unraid
- the upload staging area only if you care about preserving in-flight imports

## Scheduling

All workloads use:

```yaml
nodeSelector:
  node-type: vm
```

That keeps the service on VM-class nodes such as `nimgerianor`.

Because `beets-state` now uses `local-path`, the workload is effectively tied to the node that owns that volume. That is acceptable here because this is a NAS-attached single-node service, not an HA workload.

## Public Exposure

Only FileBrowser is public. It handles OIDC with Keycloak directly.

Current assumptions:
- public host: `ingest.dege.app`
- OIDC issuer: `https://id.mdegenaro.com/realms/theborocrew`
- callback: `https://ingest.dege.app/api/auth/oidc/callback`

## Secrets

All service secrets live in one file:

- `workload/secret.sops.yaml`

Keys scaffolded:
- `client-id`
- `client-secret`
- `BEETS_DISCOGS_TOKEN`
- `BEETS_ACOUSTID_APIKEY`

## Flux Layout

This service is now reconciled independently through its own Flux Kustomization:

- `k3s/cluster/flux/kustomization-music-ingest.yaml`

That means you can run a targeted reconcile such as:

```bash
flux reconcile kustomization music-ingest -n flux-system --with-source
```

This is intentionally separate from the aggregate `apps-nas-attached` tree so you can iterate on this service without blanket-reconciling every NAS-attached app.

## File Notes

- `workload/beets/configmap-beets.yaml`
  Contains `bootstrap.sh`, the beets config template, and lastgenre support files.
- `workload/filebrowser/configmap-filebrowser.yaml`
  FileBrowser config template with native OIDC and no password auth.
- `workload/filebrowser/deployment-filebrowser.yaml`
  Upload UI using the shared uploads PVC and a subdirectory on the beets-state PVC for its lightweight state. An initContainer renders OIDC secrets into the runtime config file.
- `workload/filebrowser/ingress-filebrowser.yaml`
  Public Traefik ingress for `ingest.dege.app`.
- `workload/beets/deployment-beets-admin.yaml`
  Long-running internal operator pod for manual imports, review, and repairs.
- `workload/beets/cronjob-auto-import.yaml`
  Main unattended import pass.
- `workload/beets/cronjob-mbsync.yaml`
  Metadata sync pass for already-tagged library items.
- `workload/beets/cronjob-replaygain.yaml`
  ReplayGain analysis pass; deliberately separate because it is slower.
- `workload/beets/cronjob-duplicates-report.yaml`
  Writes duplicate reports into the uploads logs area.
- `workload/beets/job-manual-from-logfile.yaml`
  Suspended template for reprocessing skipped imports from the import logfile.
- `workload/beets/job-manual-scrub-review.yaml`
  Suspended template for scrub-based cleanup work over review content.

## Build Step

Before reconciling the service, build and push the custom beets image from `image/`.

## Deploy Checklist

1. Fill and encrypt `workload/secret.sops.yaml`.
2. Create the Unraid directories if they do not already exist.
3. Build and push the custom beets image.
4. Create the Keycloak client and callback URL.
   Use `https://ingest.dege.app/api/auth/oidc/callback`.
5. Reconcile `music-ingest` directly.
6. Add the edge route once the in-cluster service is ready.
