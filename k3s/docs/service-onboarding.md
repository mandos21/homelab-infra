# Service Onboarding Checklist

Use this checklist when adding a new service to the k3s cluster.

The goal is to answer two questions for every service:
- what needs to be configured
- where that configuration should live in this repo

## 1. Decide the service category

- `replicated/`
  - Use for Longhorn-backed workloads that should run on the bare-metal storage nodes.
  - Repo location: `k3s/cluster/apps/replicated/<service>/`

- `nas-attached/`
  - Use for workloads that depend on Unraid/NFS storage and can run on VM nodes.
  - Repo location: `k3s/cluster/apps/nas-attached/<service>/`

Questions:
- Does this service need Longhorn-backed storage?
- Does it depend on Unraid media/data paths?
- Should it run only on bare metal, only on VM nodes, or either?

## 2. Namespace

- Create a dedicated namespace for the service unless there is a strong reason not to.
- Repo location:
  - simple layout: `k3s/cluster/apps/<category>/<service>/namespace.yaml`
  - split layout: `k3s/cluster/apps/<category>/<service>/foundation/namespace.yaml`

Questions:
- Does this service need isolation from others?
- Will this make secrets and RBAC easier to manage?

## 3. Helm source

- If installed from a Helm chart, define a `HelmRepository`.
- Repo location:
  - service-local: `k3s/cluster/apps/<category>/<service>/helmrepository.yaml`
  - shared/common sources: `k3s/cluster/apps/<category>/common/<name>/helmrepository.yaml`

Questions:
- Is there an official upstream chart?
- Do you trust the chart source?

## 4. HelmRelease or raw manifests

- Most services should use a `HelmRelease`.
- Repo location:
  - simple layout: `k3s/cluster/apps/<category>/<service>/helmrelease.yaml`
  - split layout: `k3s/cluster/apps/<category>/<service>/workload/helmrelease.yaml`

Questions:
- Is Helm the cleanest way to manage this service?
- Are there chart values you want explicit in Git instead of using upstream defaults?

## 5. Values file

- Put substantial Helm values in a separate file rather than inline in the HelmRelease.
- Repo location:
  - simple layout: `k3s/cluster/apps/<category>/<service>/values.yaml`
  - split layout: `k3s/cluster/apps/<category>/<service>/workload/values.yaml`

Questions:
- What should be explicit instead of inherited from chart defaults?
- Which values are environment-specific for your homelab?

Typical things to set:
- hostname / ingress host
- image tag if you want to pin it
- persistence settings
- resource requests/limits
- node selectors
- tolerations if needed
- service ports

## 6. Scheduling

- `replicated/` services usually need:
  - `nodeSelector: { longhorn: "enabled" }`
  - `storageClassName: longhorn` or `longhorn-3replicas`

- `nas-attached/` services usually need:
  - `nodeSelector: { node-type: "vm" }`
  - NFS-backed PVCs or static PVs

Repo location:
- usually in `values.yaml`
- sometimes in raw manifests under `workload/`

Questions:
- Where should this service run?
- Does it need 2-replica or 3-replica Longhorn storage?
- Should it avoid VM nodes or prefer them?

## 7. Persistent storage

- For Longhorn-backed apps:
  - set `storageClassName`
  - decide requested size

- For NAS-backed apps:
  - define NFS PVC/PV or use an NFS StorageClass

Repo location:
- usually in `values.yaml`
- or dedicated `foundation/pvc.yaml` / `foundation/pv.yaml`

Questions:
- Does the service actually need persistence?
- Is block storage or shared NAS storage the right fit?
- Does it need backups at the volume level, app level, or both?

## 8. Secrets

- Put credentials, tokens, client secrets, admin passwords, and API keys in SOPS-encrypted Secret manifests.
- Repo location:
  - preferred: `k3s/cluster/apps/<category>/<service>/workload/secret.sops.yaml`
  - acceptable for shared infra secrets: a dedicated infra or shared secrets directory when multiple services consume the same secret

Questions:
- What values are sensitive?
- Does the chart expect existing secrets or inline secret values?

Related files:
- `k3s/cluster/.sops.yaml`

## 9. ConfigMaps or non-secret config

- Put non-sensitive config in the service directory.
- Repo location:
  - simple layout: `k3s/cluster/apps/<category>/<service>/configmap.yaml`
  - split layout: `k3s/cluster/apps/<category>/<service>/workload/configmap.yaml`

Questions:
- What should be versioned in Git as plain config?
- What should stay out of secrets?

## 10. Ingress / exposure

- Decide whether the service should be:
  - internal only
  - LAN only
  - externally reachable through your existing edge flow

Repo location:
- `k3s/cluster/apps/<category>/<service>/workload/ingress.yaml`
- or chart values in `workload/values.yaml`

Questions:
- What hostname will it use?
- Does it need TLS?
- Will Traefik expose it directly, or will upstream Caddy proxy to k3s?
- Does it need auth in front of it?

## 11. Authentication / SSO

- Decide whether the service uses:
  - local auth only
  - OIDC / SSO
  - forward auth in front of ingress

Repo location:
- OIDC client secrets in `k3s/cluster/apps/<category>/<service>/workload/secret.sops.yaml`
- ingress auth settings in app `workload/values.yaml` or `workload/ingress.yaml`

Questions:
- Does it integrate with Keycloak or another IdP?
- Does it need admin-only access?
- Is app-native auth enough, or do you want ingress-layer auth too?

## 12. Database dependency

- Decide whether the service uses:
  - embedded database
  - separate in-cluster database
  - external database

Repo location:
- service values in `workload/values.yaml`
- database credentials in `k3s/cluster/apps/<category>/<service>/workload/secret.sops.yaml`

Questions:
- Is the embedded DB acceptable?
- Does this need PostgreSQL or MariaDB?
- How will database backups be handled?

## 13. Backup policy

- Decide whether the service needs:
  - Longhorn volume backups
  - logical application/database backups
  - both

Repo location:
- Longhorn recurring jobs under infra later
- app-specific backup jobs under the app directory
- backup docs in `k3s/docs/backups.md`

Questions:
- What is the acceptable data loss window?
- How often should backups run?
- Is restore tested?

## 14. Health and observability

- Check probes and logs.
- If the chart supports it, set readiness/liveness/startup probes explicitly.

Repo location:
- usually `workload/values.yaml`

Questions:
- Does the default probe behavior make sense?
- Is startup slow enough to need tuning?

## 15. Kustomization wiring

- Add the service directory to the appropriate app tree kustomization.

Repo locations:
- `k3s/cluster/apps/replicated/kustomization.yaml`
- `k3s/cluster/apps/nas-attached/kustomization.yaml`

Questions:
- Is the service actually included in the Flux-managed tree?

## 16. Verification after deploy

- Check Flux:
  - `flux get kustomizations -A`

- Check namespace resources:
  - `kubectl get all -n <namespace>`

- Check storage:
  - `kubectl get pvc -n <namespace>`

- Check ingress:
  - `kubectl get ingress -n <namespace>`

- Check logs:
  - `kubectl logs -n <namespace> <pod>`

Questions:
- Did the chart reconcile cleanly?
- Did the PVC bind to the intended StorageClass?
- Did the pod land on the intended nodes?
- Can you reach the app through the expected hostname/path?

## Typical file layout

For a chart-managed app:

- `k3s/cluster/apps/<category>/<service>/kustomization.yaml`
- `k3s/cluster/apps/<category>/<service>/foundation/kustomization.yaml`
- `k3s/cluster/apps/<category>/<service>/foundation/namespace.yaml`
- `k3s/cluster/apps/<category>/common/<name>/helmrepository.yaml` or service-local equivalent
- `k3s/cluster/apps/<category>/<service>/workload/kustomization.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/helmrelease.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/values.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/secret.sops.yaml`

For a raw-manifest app:

- `k3s/cluster/apps/<category>/<service>/kustomization.yaml`
- `k3s/cluster/apps/<category>/<service>/foundation/kustomization.yaml`
- `k3s/cluster/apps/<category>/<service>/foundation/namespace.yaml`
- `k3s/cluster/apps/<category>/<service>/foundation/pvc.yaml`
- `k3s/cluster/apps/<category>/<service>/foundation/pv.yaml` when static storage is needed
- `k3s/cluster/apps/<category>/<service>/workload/kustomization.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/deployment.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/service.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/ingress.yaml`
- `k3s/cluster/apps/<category>/<service>/workload/secret.sops.yaml`

## Foundation vs Workload

Use a split layout when the service has state you want to protect from routine churn.

- `foundation/` should contain slow-changing identity and storage objects:
  - namespace
  - PVCs
  - static PVs
  - sometimes shared middleware or other objects that must not be pruned casually
- `workload/` should contain the runtime layer:
  - Deployments
  - StatefulSets
  - Services
  - Ingresses
  - HelmReleases
  - ConfigMaps
  - Secrets

Why this is useful:

- storage changes are easier to review separately from image or ingress changes
- it makes data-bearing objects visually obvious during refactors
- it reduces the chance of accidentally treating PVCs like disposable runtime resources

Use a flat service directory only when the app is simple enough that the split adds noise.
