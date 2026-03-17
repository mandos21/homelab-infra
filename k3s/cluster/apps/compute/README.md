# Compute Apps

Place lab and disposable workloads here.

Scheduling defaults:
- `nodeSelector: { node-type: vm }`
- Add toleration for `node-type=vm:NoSchedule`
- Prefer `emptyDir` or non-Longhorn storage unless persistence is explicitly required
