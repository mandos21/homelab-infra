# Ingress Notes

Current repo assumptions:
- MetalLB provides LAN IPs for `LoadBalancer` Services on the mgmt network.
- Traefik is managed in-cluster under `k3s/cluster/infra/traefik/`.
- Traefik uses the default ingress class `traefik`.
- cert-manager issues the internal TLS certificate that Caddy will trust when it re-encrypts traffic to Traefik.

Important next decisions:
- Replace the starter MetalLB pool in `k3s/cluster/infra/metallb/ipaddresspool.yaml` with a DHCP-excluded range.
- Replace the starter Traefik `loadBalancerIP` in `k3s/cluster/infra/traefik/helmrelease.yaml` if you want a different fixed ingress IP.
- Replace the placeholder internal DNS names in `k3s/cluster/infra/cert-manager-config/certificate-traefik-wildcard.yaml` with the names Caddy will use when proxying to Traefik.
- Create a SOPS-managed `kubernetes.io/tls` Secret named `homelab-internal-ca-keypair` in the `cert-manager` namespace before reconciling `cert-manager-config`.

If you intend to fully replace the bundled k3s Traefik:
- `k3s/ansible/group_vars/all.yaml` now sets `k3s_disable_traefik: true` for future installs.
- Existing clusters can disable the bundled Traefik with `k3s/ansible/playbooks/disable-bundled-traefik.yaml`.
