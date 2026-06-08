# AudioMuseAI

AudioMuse-AI is grouped under `music-stack` but kept as an independent Flux app
and namespace for now.

Current deployment choices:
- separate namespace: `audiomuseai`
- upstream Helm chart managed by Flux
- built-in PostgreSQL enabled with `local-path-retain`
- upstream default `LoadBalancer` service retained for initial access
- ingress intentionally left disabled until a final host/path choice is made

After first deploy:
1. Fill and encrypt `workload/secret.sops.yaml`.
2. Reconcile the Flux `audiomuseai` Kustomization.
3. Open the UI and complete the setup wizard.
4. Wire it to Navidrome and decide whether to keep `LoadBalancer` exposure or
   move it behind Traefik.

Upstream references:
- docs: `https://neptunehub.github.io/AudioMuse-AI/`
- chart: `https://github.com/NeptuneHub/AudioMuse-AI-helm`
