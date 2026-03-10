# Adding Nodes

## Steps

1. Add the node to inventory:

```bash
vi k3s/ansible/inventory/hosts.yml
```

2. Bootstrap the node:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yml k3s/ansible/playbooks/bootstrap.yml
```

3. Join the node as a server or agent:

- Server (embedded etcd): add to `k3s_servers` and re-run:

```bash
ansible-playbook -i k3s/ansible/inventory/hosts.yml k3s/ansible/playbooks/k3s-ha.yml
```

4. Apply labels/taints as needed:

```bash
kubectl label node <node> compute=standard --overwrite
kubectl label node <node> storage.longhorn.io/eligible=false --overwrite
```

5. Verify:

```bash
kubectl get nodes
kubectl -n longhorn-system get nodes
```
