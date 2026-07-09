# Home Assistant Stack

This namespace groups:
- Home Assistant
- Mosquitto
- MQTT Explorer

Mosquitto is exposed on the LAN via MetalLB at `192.168.1.4` on ports `1883` and `8883`.

Notes:
- Home Assistant runs with `hostNetwork: true` for LAN-native discovery behavior.
- `/media` is backed by `emptyDir` and is treated as non-persistent scratch space.
- No USB device passthrough is configured.
- Home Assistant is exposed at `home.dege.app`. MQTT Explorer remains internal-only.

## Migration

1. Reconcile the app.
2. Start the migration pod.
3. Copy each source config tree into its target PVC.
4. Bring the workloads up.

Create the migration pod:

```bash
kubectl apply -f k3s/cluster/apps/longhorn-backed/home-assistant/migration/pod-copy-config.yaml
kubectl wait --for=condition=Ready pod/home-assistant-copy-config -n home-assistant --timeout=180s
kubectl exec -it -n home-assistant pod/home-assistant-copy-config -- sh
```

Inside the pod:

```sh
mkdir -p /target/homeassistant /target/mosquitto /target/mqtt-explorer

tar -C /source/homeassistant -cf - . | tar -C /target/homeassistant -xf -
tar -C /source/mosquitto -cf - . | tar -C /target/mosquitto -xf -
tar -C /source/mqtt-explorer -cf - . | tar -C /target/mqtt-explorer -xf -

chown -R 99:100 /target/homeassistant
```

Then delete the migration pod:

```bash
kubectl delete pod home-assistant-copy-config -n home-assistant
```
