# Edge Automation

- `edge/ansible/playbooks/caddy-config.yaml`: render, validate, and reload the edge Caddy configuration
- `edge/ansible/playbooks/edge-services.yaml`: deploy supporting edge services such as Uptime Kuma and the fallback page
- `edge/ansible/playbooks/step-ca-bootstrap.yaml`: bootstrap the dedicated edge step-ca instance for k3s ingress PKI
- `edge/ansible/group_vars/secrets.sops.yaml`: SOPS-encrypted edge secrets, including the Cloudflare API token for Caddy
