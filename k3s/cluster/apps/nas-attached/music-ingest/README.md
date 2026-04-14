# Music Ingest

Music ingest is a `nas-attached` service because it depends on Unraid-backed media shares and is intended to run on VM-class nodes.

## Host and Routing Notes

You asked about consolidating related services under one host:

- `music.dege.app` for Navidrome
- `music.dege.app/tags` for Picard
- `music.dege.app/ingest` for this ingest service

This is feasible, but not equally clean for every app.

- Navidrome is the easiest of the three because it supports a configurable base URL.
- Picard is workable behind a subpath, but desktop-webapp wrappers tend to be a little less pleasant than a root-host deployment.
- oauth2-proxy plus FileBrowser behind `/ingest` is workable, but the callback URL, auth prefix, and upstream path handling all become stricter.

So the migration cost is moderate rather than high. It is mostly proxy/routing work, not application redesign.

## Layout

- `foundation/`
  Namespace and storage primitives: static NFS PVs, their PVCs, and the local beets-state PVC.
- `workload/`
  Runtime layer for the service. Shared secret and Traefik middleware live here.
- `workload/oauth2-proxy/`
  HelmRelease for the public auth gateway.
- `workload/filebrowser/`
  Internal upload UI manifests. Raw manifests are used here because the public chart insists on owning its own PVCs, which conflicts with the shared upload staging design.
- `workload/beets/`
  Single-replica admin runtime, scheduled import/maintenance jobs, suspended manual repair jobs, and the beets ConfigMap.
- `image/`
  Custom beets image scaffold built on the LSIO beets image.

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

Only `oauth2-proxy` is public. It fronts the internal FileBrowser service and handles OIDC with Keycloak.

Current assumptions:
- public host: `music.dege.app`
- public path prefix: `/ingest`
- OIDC issuer: `https://id.mdegenaro.com/realms/theborocrew`
- callback: `https://music.dege.app/ingest/oauth2/callback`

## Secrets

All service secrets live in one file:

- `workload/secret.sops.yaml`

Keys scaffolded:
- `client-id`
- `client-secret`
- `cookie-secret`
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
  Internal FileBrowser config; proxy auth only, no direct password login.
- `workload/filebrowser/deployment-filebrowser.yaml`
  Internal-only upload UI using the shared uploads PVC and a subdirectory on the beets-state PVC for its lightweight state.
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
5. Reconcile `music-ingest` directly.
6. Add the edge route once the in-cluster service is ready.
