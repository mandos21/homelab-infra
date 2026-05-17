# k3s etcd S3 backups

This playbook adds a K3s config drop-in on each server node so scheduled embedded-etcd snapshots are uploaded directly to Garage.

It uses:
- K3s config drop-ins under `/etc/rancher/k3s/config.yaml.d`
- serial restarts of the `k3s` service, one server at a time
- SOPS + age for the Garage access key and secret key

Reference docs:
- K3s config drop-ins: `https://docs.k3s.io/installation/configuration`
- K3s etcd snapshot S3 options: `https://docs.k3s.io/cli/etcd-snapshot`

## Before running

1. Update `k3s/ansible/etcd-s3-backups.vars.yaml`
2. Edit `k3s/ansible/group_vars/secrets.sops.yaml`
3. Set `k3s_etcd_backup_s3_access_key`
4. Set `k3s_etcd_backup_s3_secret_key`
5. Re-encrypt the secrets file with `cd k3s && sops --encrypt --in-place ansible/group_vars/secrets.sops.yaml`
6. Verify Garage bucket `homelab-etcd` exists and the key has read/write access

The playbook expects the `community.sops` Ansible collection to be available on the control machine.

## Secret file workflow

Do not run `sops` against `k3s/ansible/etcd-s3-backups.vars.yaml`.
That file is intentionally plain YAML and does not contain SOPS metadata.
Only `k3s/ansible/group_vars/secrets.sops.yaml` should be edited with `sops`.

Decrypt for editing:

```bash
sops k3s/ansible/group_vars/secrets.sops.yaml
```

View decrypted contents without editing:

```bash
sops --decrypt k3s/ansible/group_vars/secrets.sops.yaml
```

If you run the command from inside the `k3s/` directory, use:

```bash
sops ansible/group_vars/secrets.sops.yaml
```

That path matches the creation rule in `k3s/.sops.yaml`:

```yaml
path_regex: ^ansible/group_vars/.*\.sops\.yaml$
```

## Apply

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
ansible-playbook -i k3s/ansible/inventory/hosts.yaml \
  k3s/ansible/playbooks/k3s-etcd-s3-backups.yaml
```

## After apply

Run one manual test snapshot on a server node:

```bash
sudo k3s etcd-snapshot save --name on-demand-test
sudo k3s etcd-snapshot ls
```

`k3s etcd-snapshot save` may print warnings about unrelated server config keys such as
`--disable` or `--etcd-snapshot-schedule-cron` being unknown. This is expected when the
subcommand reads the full K3s config file and skips options that are only used by the
server process. If the snapshot is created and uploaded successfully, these warnings are
not a backup configuration failure.

Then confirm the object appears in Garage under:
- bucket: `homelab-etcd`
- prefix: `cluster1/`
