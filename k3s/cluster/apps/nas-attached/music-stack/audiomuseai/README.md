# AudioMuseAI

AudioMuse-AI is grouped under `music-stack` but kept as an independent Flux app
and namespace for now.

Current deployment choices:
- separate namespace: `audiomuseai`
- upstream Helm chart managed by Flux
- built-in PostgreSQL enabled with `local-path-retain`
- UI exposed at `music-ai.dege.app` behind `oauth2-proxy`
- app service kept internal as `ClusterIP`

After first deploy:
1. Fill and encrypt `workload/secret.sops.yaml`.
2. Fill and encrypt `workload/secret-oauth2.sops.yaml`.
3. Reconcile the Flux `audiomuseai` Kustomization.
4. Open the UI and complete the setup wizard.
5. In AudioMuse, use in-cluster backend URLs:
   - Navidrome: `http://navidrome.navidrome.svc.cluster.local:80`
   - Ollama: `http://ollama.llm.svc.cluster.local:11434`
6. If you reuse the Picard OIDC client, add `https://music-ai.dege.app/oauth2/callback`
   to that client's allowed redirect URIs.

Security notes:
- AudioMuse internal auth can stay disabled because access is enforced at the
  edge by `oauth2-proxy`.
- Backend integrations should use cluster DNS, not public hosts, so service-to-service
  traffic stays inside the cluster and does not depend on external ingress.

Upstream references:
- docs: `https://neptunehub.github.io/AudioMuse-AI/`
- chart: `https://github.com/NeptuneHub/AudioMuse-AI-helm`
