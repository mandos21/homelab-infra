# Homelab Infra

This repo manages the current homelab as:
- `k3s` on three bare-metal control-plane/storage nodes
- GitOps-managed cluster manifests under `k3s/cluster/`
- Ansible-managed node bootstrap and lifecycle under `k3s/ansible/`
- separate edge automation under `edge/`

The old Docker Compose `stacks/` tree is no longer the primary deployment model. Some content there is still useful as migration history or for a small number of legacy workloads, but the active platform is the `k3s/` tree.

## Current layout

```text
homelab-infra/
├── README.md                  # repo overview and doc index
├── docs/                      # historical notes and migration leftovers
├── edge/                      # edge host automation and docs
├── k3s/                       # active cluster code, runbooks, and app manifests
├── stacks/                    # mostly legacy compose stacks and migration artifacts
└── renovate.json              # image update automation
```

## What lives where

### `k3s/`

This is the main platform.

- `k3s/ansible/`
  - host inventory
  - node bootstrap
  - k3s install and upgrade playbooks
  - Longhorn disk prep
  - etcd-to-Garage backup configuration
- `k3s/cluster/`
  - Flux-managed cluster manifests
  - infra components such as Traefik, Longhorn, MetalLB, cert-manager
  - app manifests split into `replicated/` and `nas-attached/`
- `k3s/docs/`
  - operational runbooks and recovery docs

### `edge/`

This holds the separate edge host automation, including:
- Caddy config deployment
- edge support services
- dedicated step-ca bootstrap for ingress PKI

### `stacks/`

This is no longer the default deployment path. Keep it as:
- migration history
- reference configs from the pre-k3s setup
- a place for anything that still intentionally runs outside the cluster

If a service is active in k3s, prefer the docs and manifests under `k3s/` over anything under `stacks/`.

## Operating model

### Cluster lifecycle

Use Ansible for node preparation and K3s lifecycle:
- inventory: [k3s/ansible/inventory/hosts.yaml](/Users/mandos/dev/homelab-infra/k3s/ansible/inventory/hosts.yaml)
- shared defaults: [k3s/ansible/group_vars/all.yaml](/Users/mandos/dev/homelab-infra/k3s/ansible/group_vars/all.yaml)
- main runbook: [k3s/docs/README.md](/Users/mandos/dev/homelab-infra/k3s/docs/README.md)

### Cluster desired state

Use Flux-managed manifests under `k3s/cluster/` for:
- core infra
- storage classes
- ingress
- applications
- encrypted Kubernetes secrets

### Secrets

SOPS is used in two contexts:
- `k3s/cluster/.sops.yaml` for in-cluster Kubernetes secrets
- `k3s/.sops.yaml` and `edge/.sops.yaml` for Ansible-side encrypted vars

Relevant docs:
- [k3s/docs/secrets.md](/Users/mandos/dev/homelab-infra/k3s/docs/secrets.md)
- [edge/docs/README.md](/Users/mandos/dev/homelab-infra/edge/docs/README.md)

## Documentation index

### Core runbooks

- [k3s/docs/README.md](/Users/mandos/dev/homelab-infra/k3s/docs/README.md): primary K3s setup and operations runbook
- [k3s/docs/backups.md](/Users/mandos/dev/homelab-infra/k3s/docs/backups.md): current backup coverage, restore procedures, and gaps
- [k3s/docs/adding-nodes.md](/Users/mandos/dev/homelab-infra/k3s/docs/adding-nodes.md): adding or replacing nodes
- [k3s/docs/ingress.md](/Users/mandos/dev/homelab-infra/k3s/docs/ingress.md): ingress and traffic flow
- [k3s/docs/flux-debugging.md](/Users/mandos/dev/homelab-infra/k3s/docs/flux-debugging.md): Flux troubleshooting
- [k3s/docs/secrets.md](/Users/mandos/dev/homelab-infra/k3s/docs/secrets.md): SOPS + age workflow

### Storage and backup docs

- [k3s/ansible/README-etcd-backups.md](/Users/mandos/dev/homelab-infra/k3s/ansible/README-etcd-backups.md): playbook-level etcd backup setup
- [k3s/docs/backups.md](/Users/mandos/dev/homelab-infra/k3s/docs/backups.md): operational restore procedures and current backup status
- [k3s/cluster/apps/replicated/README.md](/Users/mandos/dev/homelab-infra/k3s/cluster/apps/replicated/README.md): replicated app conventions
- [k3s/cluster/apps/nas-attached/README.md](/Users/mandos/dev/homelab-infra/k3s/cluster/apps/nas-attached/README.md): NAS-attached app conventions

### Edge docs

- [edge/docs/README.md](/Users/mandos/dev/homelab-infra/edge/docs/README.md): edge automation overview
- [edge/docs/step-ca.md](/Users/mandos/dev/homelab-infra/edge/docs/step-ca.md): dedicated step-ca notes

### Service-specific docs

Examples of workload-level docs that matter during migrations or restore work:
- [k3s/cluster/apps/replicated/keycloak/README.md](/Users/mandos/dev/homelab-infra/k3s/cluster/apps/replicated/keycloak/README.md)
- [k3s/cluster/apps/nas-attached/navidrome/README.md](/Users/mandos/dev/homelab-infra/k3s/cluster/apps/nas-attached/navidrome/README.md)
- [stacks/moved-to-k3s/keycloak/README.md](/Users/mandos/dev/homelab-infra/stacks/moved-to-k3s/keycloak/README.md)

## Backup status

Current state:
- embedded etcd snapshots are configured on the k3s servers and replicated to Garage
- local etcd snapshots still exist on each server node
- Longhorn volume backups are not yet configured to use Garage
- application-level logical backups are still service-specific, not centralized
- NAS-attached data is not covered by the k3s control-plane backup path

Read [k3s/docs/backups.md](/Users/mandos/dev/homelab-infra/k3s/docs/backups.md) before making storage or recovery changes. That file is the source of truth for current backup and restore procedure.

## Legacy notes

Historical notes remain under:
- [docs/migration-notes.md](/Users/mandos/dev/homelab-infra/docs/migration-notes.md)
- `stacks/`

Treat them as reference material unless a service is still intentionally running there.
