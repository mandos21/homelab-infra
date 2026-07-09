# Longhorn-Backed Apps

Place Longhorn-backed workloads here.

Scheduling defaults:
- `nodeSelector: { longhorn: "enabled" }`
- Use `storageClassName: longhorn` for persistent volumes
- Suitable for stateful or HA-oriented services such as authentication, Vaultwarden, and collaboration tools
