# Dedicated Step-CA For k3s

This playbook bootstraps a second `step-ca` instance specifically for the under-construction k3s environment.

Why a separate instance:
- it keeps the existing Docker/Unraid certificate flow unchanged
- it gives k3s its own CA endpoint, provisioner, and lifecycle
- it avoids coupling the cluster to a rotating cert-copy script

Recommended identity model:
- CA URL: `https://stepca.admengyl.lan:9001`
- dedicated provisioner: `k3s-step-issuer`
- backend ingress certificate identity: separate from the CA host identity, e.g. `traefik.cluster1.lan`

## Inventory

Add the CA host under `step_ca_hosts` in `k3s/ansible/inventory/hosts.yaml`.

Example:

```yaml
step_ca_hosts:
  hosts:
    admengyl:
      ansible_host: 192.168.1.X
```

## Required inputs

The playbook expects two local files on the control machine:
- `step_ca_password_file_src`: password file for the new CA root/intermediate
- `step_ca_provisioner_password_file_src`: password file for the dedicated JWK provisioner

Pass them as inventory vars, host vars, or `-e` extra vars.

Example:

```bash
ansible-playbook \
  -i k3s/ansible/inventory/hosts.yaml \
  k3s/ansible/playbooks/step-ca-bootstrap.yaml \
  --limit admengyl \
  -e step_ca_password_file_src=/secure/step-ca/password.txt \
  -e step_ca_provisioner_password_file_src=/secure/step-ca/provisioner-password.txt
```

## What the playbook does

- creates `/opt/k3s-step-ca`
- initializes a new `step-ca` with a dedicated JWK provisioner
- runs it via Docker Compose on port `9001`
- fetches the root and intermediate certificates to `k3s/ansible/artifacts/step-ca/<host>/`

## Current assumptions

- Docker and `docker compose` already exist on the CA host
- `stepca.admengyl.lan` resolves to that host
- running in parallel with the existing step-ca on a different port is acceptable

## Next step after bootstrap

After this CA is up:
- install `step-issuer` in the cluster
- create a `StepClusterIssuer`
- issue the Traefik backend certificate from this CA instead of copying rotating leaf certs around

Before reconciling the step-issuer configuration:
- rerun `k3s/ansible/playbooks/step-ca-bootstrap.yaml` once after the latest repo changes so `bootstrap.txt` includes the provisioner `kid`
- create the provisioner password secret in `step-issuer-system`, for example:

```bash
kubectl -n step-issuer-system create secret generic step-issuer-provisioner-password \
  --from-file=password=/secure/step-ca/provisioner-password.txt
```
