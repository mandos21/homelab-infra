# LLM Stack

This namespace groups the local LLM and voice-assistant services that are operationally coupled:
- `ollama`
- `openwebui`
- `kokoro`
- `openwakeword`
- `wyoming-faster-whisper`

Design choices:
- the stack remains `nas-attached` because the long-lived model stores and caches live on the NAS
- `ollama` keeps the existing GPU pinning and LAN `LoadBalancer` exposure
- `openwebui` is the public browser entrypoint at `chat.dege.app`
- Open WebUI uses native OIDC against `https://id.dege.app/realms/theborocrew`
- the Wyoming services stay cluster-internal for Home Assistant and related consumers

Storage layout:
- `/mnt/user/appdata/ollama` stays mounted into `ollama-data`
- Open WebUI state lives in the `openwebui-data` PVC
- `/mnt/user/appdata/faster-whisper` stays mounted into `wyoming-faster-whisper-data`

Important OIDC notes:
- Open WebUI requires the redirect URI `https://chat.dege.app/oauth/oidc/callback`
- `WEBUI_URL` must remain aligned with the public URL before first login
- `secret.sops.yaml` is intentionally left unencrypted here so it can be encrypted locally before reconcile
