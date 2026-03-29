# Ingress Notes

Current repo assumptions:
- MetalLB provides LAN IPs for `LoadBalancer` Services on the mgmt network.
- Traefik is managed in-cluster under `k3s/cluster/infra/traefik/`.
- Traefik uses the default ingress class `traefik`.
- Traefik needs a single backend TLS certificate that Caddy will trust when it re-encrypts traffic to Traefik.

Important next decisions:
- Replace the starter MetalLB pool in `k3s/cluster/infra/metallb/resources.yaml` with a DHCP-excluded range.
- Replace the starter Traefik `loadBalancerIP` in `k3s/cluster/infra/traefik/resources.yaml` if you want a different fixed ingress IP.
- The backend certificate presented by Traefik should cover `traefik.tadolithron.lan`, matching the SNI in the existing Caddy config.
- `k3s/cluster/infra/traefik-config/resources.yaml` makes Traefik serve the `traefik-backend-tls` secret as its default certificate.
- If you keep the current step-ca timer model, update `traefik-backend-tls` operationally rather than storing a rotating PKI secret in Git.

If you intend to fully replace the bundled k3s Traefik:
- `k3s/ansible/group_vars/all.yaml` now sets `k3s_disable_traefik: true` for future installs.
- Existing clusters can disable the bundled Traefik with `k3s/ansible/playbooks/disable-bundled-traefik.yaml`.
