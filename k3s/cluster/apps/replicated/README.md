# Replicated Apps

Place Longhorn-backed workloads here.

Scheduling defaults:
- `nodeSelector: { longhorn: "enabled" }`
- Use `storageClassName: longhorn` for persistent volumes
- Suitable for replicated or HA-oriented services such as authentication, Vaultwarden, and collaboration tools
