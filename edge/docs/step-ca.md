# Edge Step-CA

The dedicated step-ca instance for the k3s ingress PKI is managed from `edge/ansible/`.

Inventory:
- `edge/ansible/inventory/hosts.yaml`

Bootstrap playbook:
- `edge/ansible/playbooks/step-ca-bootstrap.yaml`

Preferred secret source:
- store `step_ca_password` and `step_ca_provisioner_password` in `edge/ansible/group_vars/secrets.sops.yaml`

Example:

```bash
ansible-playbook \
  -i edge/ansible/inventory/hosts.yaml \
  edge/ansible/playbooks/step-ca-bootstrap.yaml \
  --limit admengyl
```

For edge-host secrets such as Caddy's Cloudflare token:
- edit `edge/ansible/group_vars/secrets.sops.yaml`
- encrypt/decrypt it with the SOPS policy in `edge/.sops.yaml`

Optional fallback:
- you can still pass `step_ca_password_file_src` and `step_ca_provisioner_password_file_src` if you need to bootstrap from local files instead
