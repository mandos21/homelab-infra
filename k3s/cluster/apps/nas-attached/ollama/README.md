# Ollama

Ollama is modeled as a `nas-attached` single-replica service because its model store already lives on the NAS at `/mnt/user/appdata/ollama`.

This scaffold intentionally mounts that existing NAS path directly over NFS instead of copying model data into a new PVC. That makes the cutover simple: once the old Docker container is stopped, the k3s pod can use the same backing data.

Important assumptions:
- The GPU is passed through to `nimgerianor`, and that VM can use it directly. This scaffold pins the workload to `kubernetes.io/hostname=nimgerianor`.
- NVIDIA device plugin support is available in the cluster, so `nvidia.com/gpu: 1` can schedule.
- No public ingress is created yet. The service is exposed on the LAN with a `LoadBalancer` service and remains reachable in-cluster at `ollama:11434`.

Suggested cutover:
1. Reconcile the manifests.
2. Confirm the `ollama-data` PVC is `Bound`.
3. Stop the old Docker `ollama` container.
4. Scale the k3s deployment up if you have kept it at `0`, or let it start and validate scheduling on the GPU node.
5. Test from inside the cluster with `curl http://ollama:11434/api/tags` and from the LAN against the assigned `LoadBalancer` IP.
