# Core Apps

Place must-stay-up workloads here.

Scheduling defaults:
- `nodeSelector: { node-type: baremetal }`
- No toleration for `node-type=vm:NoSchedule`
- Use `storageClassName: longhorn` for persistent state when appropriate
