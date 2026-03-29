# k3s Runbook

Assumptions:
- Control machine is Linux (Ubuntu 24.04 or similar)
- Repo cloned locally and you run commands from repo root
- Bare-metal servers: minandras, tadandras, nelandras (Ubuntu 24.04)
- Optional VM workers join as k3s agents only

## 0) One-time prep

1. Update inventory + vars:
   - `k3s/ansible/inventory/hosts.yaml`
   - `k3s/ansible/group_vars/all.yaml`

2. Network layout (per node):
   - `mgmt` (1GbE) for SSH/Internet: `192.168.1.0/24`
   - `stor` (2.5GbE) for k3s/Longhorn east-west: `192.168.3.0/24`
   - Ensure you set `mgmt_ip`, `stor_ip`, MACs, `k3s_role`, `node_type`, and `longhorn_eligible` in inventory.

3. Ensure SSH access to all nodes:

```bash
ssh ansible@192.168.1.245
ssh ansible@192.168.1.153
ssh ansible@192.168.1.243
```

## 1) Install control-machine tooling

```bash
sudo apt update
sudo apt install -y ansible curl jq git

# kubectl
curl -fsSL https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl \
  -o /usr/local/bin/kubectl
sudo chmod +x /usr/local/bin/kubectl

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# flux
curl -fsSL https://fluxcd.io/install.sh | sudo bash

# sops
sudo apt install -y sops

# age
sudo apt install -y age
```

## 2) Bootstrap nodes (swap off, packages, iscsid, etc)

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yaml k3s/ansible/playbooks/bootstrap.yaml
```

If a node is not ready (e.g., missing MACs), use `--limit`:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yaml k3s/ansible/playbooks/bootstrap.yaml --limit minandras,tadandras
```

Note: If udev rules changed, nodes will reboot to apply stable NIC names.

## 3) Install k3s HA (embedded etcd)

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yaml k3s/ansible/playbooks/k3s-ha.yaml
```

This installs k3s with `--node-ip` and `--flannel-iface` set to the stor network.
Servers join as embedded-etcd control-plane nodes. VM workers, if present in `k3s_agents`, join as agents only.
Node labels applied by Ansible:
- Bare metal storage nodes: `node-type=baremetal`, `longhorn=enabled`
- VM workers: `node-type=vm`, `longhorn=disabled`

If the cluster already exists and you want to remove the bundled k3s Traefik in favor of the repo-managed Traefik release, run:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yaml k3s/ansible/playbooks/disable-bundled-traefik.yaml
```

## 3a) Upgrade k3s later

Set the target version in `k3s/ansible/group_vars/all.yaml`, then run:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yaml k3s/ansible/playbooks/k3s-upgrade.yaml
```

The upgrade playbook upgrades:
- the init server first
- the remaining servers one at a time
- the agent nodes one at a time

## 4) Configure kubeconfig on control machine

1. Copy kubeconfig from `minandras`:

```bash
scp ansible@192.168.1.245:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

2. Update the server address in kubeconfig:

```bash
sed -i 's/127.0.0.1/192.168.1.245/' ~/.kube/config
```

3. Verify:

```bash
kubectl get nodes
kubectl get pods -A
```

## 5) SOPS + age setup

1. Create an age keypair:

```bash
age-keygen -o age.key
```

2. Export public key for `.sops.yaml`:

```bash
age-keygen -y age.key
```

3. Update `k3s/cluster/.sops.yaml` with your public key.

4. Create the in-cluster age key secret:

```bash
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=age.key
```

5. Encrypt a secret (example):

```bash
sops --encrypt --in-place k3s/cluster/secrets/example-secret.sops.yaml
```

## 6) Flux bootstrap (GitHub)

1. Create a GitHub PAT with repo access (or use a GitHub App).

2. Bootstrap Flux (replace placeholders):

```bash
export GITHUB_TOKEN=YOUR_PAT
flux bootstrap github \
  --owner=<GITHUB_OWNER> \
  --repository=homelab-infra \
  --branch=main \
  --path=./k3s/cluster/flux \
  --personal
```

Note: Flux will commit manifests into `k3s/cluster/flux`. Keep the sample files consistent with your repo URL, branch, and path.

3. Verify Flux:

```bash
flux get kustomizations -A
kubectl get pods -n flux-system
```

## 7) Apply initial infra manifests

Flux will reconcile `k3s/cluster/infra` automatically. The repo now includes scaffolding for:
- cert-manager
- MetalLB
- Traefik
- Longhorn

Ensure cert-manager installs:

```bash
kubectl get pods -n cert-manager
```

## 8) Longhorn and MetalLB (later)

Do not enable Longhorn or MetalLB until you have:
- MetalLB address pool decided
- Disks prepped for Longhorn

Prepare the dedicated Longhorn disks on the bare-metal nodes first:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yaml k3s/ansible/playbooks/longhorn-disk-prep.yaml
```

The disk prep playbook:
- detects the single non-OS disk
- refuses to proceed if detection is ambiguous
- creates a GPT partition table only on a blank disk
- creates an `ext4` filesystem only if none exists
- mounts it at `/var/lib/longhorn` by default via `UUID=...`
- updates `/etc/fstab` idempotently

Use the mgmt LAN for MetalLB (e.g., `192.168.1.0/24`). Keep the stor network internal.

See `k3s/docs/ingress.md`.

## 9) Add apps

Use the repo split consistently:
- `k3s/cluster/apps/replicated/` for Longhorn-backed HA workloads
- `k3s/cluster/apps/nas-attached/` for workloads coupled to Unraid or NAS storage

Scheduling defaults:
- Replicated apps: `nodeSelector: { longhorn: "enabled" }`
- Replicated apps: use `storageClassName: longhorn` for PVCs
- NAS-attached apps: `nodeSelector: { node-type: "vm" }`
- NAS-attached apps: use NFS-backed PVCs, static NFS PVs, or equivalent Unraid-backed storage
- Secrets stay under `k3s/cluster/secrets/` for both app trees

## 10) Backups and restore

See `k3s/docs/backups.md`.

## 11) Dedicated step-ca for k3s

If you want a separate Smallstep CA for the k3s environment instead of reusing the existing Docker PKI flow, see `k3s/docs/step-ca.md`.

## 12) Add nodes later

See `k3s/docs/adding-nodes.md`.
