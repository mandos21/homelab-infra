# etcd Restore Playbook

Use this playbook for control-plane recovery of the embedded-etcd cluster.

## Backups used

- local snapshots under `/var/lib/rancher/k3s/server/db/snapshots`
- Garage bucket `homelab-etcd`, prefix `cluster1/`

## Preconditions

You need:

- the snapshot filename you want to restore
- the original k3s server token from `/var/lib/rancher/k3s/server/token`
- shell access to all control-plane nodes

Current control-plane nodes:

- `minandras`
- `tadandras`
- `nelandras`

## Pick the snapshot

On a healthy or partially healthy server:

```bash
sudo k3s etcd-snapshot ls
kubectl get etcdsnapshotfile
```

Garage-backed restores use the snapshot filename, not the full S3 URL.

## Restore from Garage to the existing hosts

1. Stop k3s on all control-plane nodes.

```bash
sudo systemctl stop k3s
```

2. On the initial restore node, run the cluster reset.

```bash
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=<SNAPSHOT-FILENAME>
```

3. Start k3s again on the restore node.

```bash
sudo systemctl start k3s
```

4. On the peer control-plane nodes, remove the old etcd data.

```bash
sudo rm -rf /var/lib/rancher/k3s/server/db/
```

5. Start k3s again on the peer nodes.

```bash
sudo systemctl start k3s
```

## Restore from a local snapshot file when S3 config is present

If you are restoring from a local file and the node config still contains S3 settings, disable S3 explicitly for the restore command.

```bash
sudo k3s server \
  --cluster-reset \
  --etcd-s3=false \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<SNAPSHOT-FILE>
```

Then follow the same peer rejoin steps.

## Restore to replacement hosts

On the first replacement control-plane host:

```bash
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT> \
  --token=<BACKED-UP-TOKEN>
```

Then join the replacement peer servers normally using the same backed-up token and matching cluster configuration.

## Validation

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get etcdsnapshotfile
sudo systemctl status k3s
sudo journalctl -u k3s -n 100 --no-pager
```

Confirm:

- all expected control-plane nodes rejoined
- Flux and core infra pods recovered
- the cluster can still see snapshot objects
