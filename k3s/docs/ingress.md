# Ingress Notes

Current repo assumptions:
- MetalLB provides LAN IPs for `LoadBalancer` Services on the mgmt network.
- Traefik is managed in-cluster under `k3s/cluster/infra/traefik/`.
- Traefik uses the default ingress class `traefik`.
- Traefik needs a single backend TLS certificate that Caddy will trust when it re-encrypts traffic to Traefik.

Important next decisions:
- Replace the starter MetalLB pool in `k3s/cluster/infra/metallb/resources.yaml` with a DHCP-excluded range.
- Replace the starter Traefik `loadBalancerIP` in `k3s/cluster/infra/traefik/resources.yaml` if you want a different fixed ingress IP.
- The backend certificate presented by Traefik should cover `traefik.cluster1.lan`, matching the SNI you will configure in Caddy for the k3s ingress hop.
- `k3s/cluster/infra/traefik-config/resources.yaml` makes Traefik serve the `traefik-backend-tls` secret as its default certificate.
- `k3s/cluster/infra/step-issuer/resources.yaml` installs the step-issuer controller that cert-manager will use to request backend certificates from the dedicated step-ca.
- `k3s/cluster/infra/cert-manager-config/resources.yaml` now defines a `StepClusterIssuer` plus the Traefik backend `Certificate`.
- Create a Secret named `step-issuer-provisioner-password` in `step-issuer-system` before reconciling the issuer config.

If you intend to fully replace the bundled k3s Traefik:
- `k3s/ansible/group_vars/all.yaml` now sets `k3s_disable_traefik: true` for future installs.
- Existing clusters can disable the bundled Traefik with `k3s/ansible/playbooks/disable-bundled-traefik.yaml`.
