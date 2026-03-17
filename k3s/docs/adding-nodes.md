# Adding Nodes

## Steps

1. Add the node to inventory:

```bash
vi k3s/ansible/inventory/hosts.yml
```

Set these host vars:
- `k3s_role=server` for bare-metal control-plane/storage nodes
- `k3s_role=agent` for VM workers
- `node_type=baremetal` or `node_type=vm`
- `longhorn_eligible=true` only for bare-metal nodes with prepared storage

Ansible will translate this into node labels:
- `node-type=baremetal` plus `longhorn=enabled` on Longhorn-capable bare metal
- `node-type=vm` plus `longhorn=disabled` on VM workers

2. Bootstrap the node:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yml k3s/ansible/playbooks/bootstrap.yml
```

3. Join the node as a server or agent:

- Server (embedded etcd): add to `k3s_servers` and re-run:
- Agent (VM worker): add to `k3s_agents` and re-run:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yml k3s/ansible/playbooks/k3s-ha.yml
```

4. Labels are applied automatically from inventory by `k3s/ansible/playbooks/k3s-ha.yml`.

5. Verify:

```bash
kubectl get nodes
kubectl -n longhorn-system get nodes
k3s kubectl describe node <node>
```
