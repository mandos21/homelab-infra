# Flux Debugging

When a `flux reconcile kustomization ...` appears to hang, the usual cause is not Flux itself. Flux is typically waiting on a dependency, a Helm release, or a health check.

Use this sequence to debug it.

## 1) Check Kustomization status

```bash
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A
```

This tells you:
- which Kustomization is not ready
- whether the problem is a dependency, apply failure, or health check failure

## 2) Describe the failing Kustomization

```bash
kubectl describe kustomization <name> -n flux-system
```

This is the most useful command.

Look for:
- `Message`
- `Reason`
- `Events`

Typical examples:
- `dependency 'flux-system/infra' is not ready`
- `dry-run failed: no matches for kind ...`
- `health check failed ... stalled resources`

## 3) Check HelmRelease status

```bash
flux get helmreleases -A
```

If a Kustomization contains Helm releases, this usually reveals the real blocker.

Examples:
- chart values schema errors
- hook job failures
- image pull failures
- install/upgrade timeouts

## 4) Check runtime state

```bash
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
```

Use this when the manifests applied but workloads are not becoming healthy.

Typical examples:
- `ErrImagePull`
- `CrashLoopBackOff`
- pending pods due to scheduling
- failed jobs

## 5) Reconcile in dependency order

Do not reconcile everything at once if the stack has explicit ordering.

Typical pattern in this repo:

```bash
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization infra -n flux-system --with-source
flux reconcile kustomization metallb-config -n flux-system --with-source
flux reconcile kustomization cert-manager-config -n flux-system --with-source
flux reconcile kustomization traefik-config -n flux-system --with-source
```

## Common failure patterns

### CRD object applied too early

Symptom:
- `no matches for kind ...`

Cause:
- a CRD-backed object is being applied before the controller/chart that installs the CRD

Fix:
- move those CRs into a later Kustomization that depends on the controller install

### HelmRelease schema failure

Symptom:
- HelmRelease shows chart values schema errors

Cause:
- values do not match the chart version you pinned

Fix:
- inspect the exact HelmRelease message
- compare values with the chart's expected schema

### Health check failed on stalled resources

Symptom:
- Kustomization says `health check failed`

Cause:
- one or more resources applied, but never became healthy

Fix:
- inspect the named stalled resource directly
- for Helm releases, start with `flux get helmreleases -A`

### Dependency not ready

Symptom:
- downstream Kustomizations stay not ready

Cause:
- upstream Kustomization is failing

Fix:
- ignore downstream noise
- fix the first upstream failure

## Practical rule

Always debug the first failing dependency, not the last thing you tried to reconcile.
