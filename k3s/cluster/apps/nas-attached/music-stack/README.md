# Music Stack

This folder groups the music-related `nas-attached` applications so they can
evolve together without changing their independent Flux reconciliation model.

Current members:
- `music-ingest`
- `navidrome`
- `picard`

Each app still keeps its own `foundation/` and `workload/` split and still
reconciles through its own Flux `Kustomization`.
