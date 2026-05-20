# Home Assistant Restore Playbook

Home Assistant uses its native backup system as the primary restore path.
Longhorn remains the lower-level storage fallback.

## Backup source

- Home Assistant native backup stored to the configured Garage-backed location
- optional local backup copies exported from the UI

## Preferred restore path

Use the Home Assistant backup UI and follow the standard Home Assistant restore flow.

Two common cases:

1. restore during onboarding to a replacement instance
2. restore onto the current system from `Settings -> System -> Backups`

Reference flow from the current Home Assistant docs:

- onboarding restore: upload or select the backup during initial setup
- in-place restore: select the backup in the UI and choose what to restore

## Operational notes for this cluster

- Home Assistant runs on a Longhorn-backed PVC, so Longhorn recovery is available if the native backup path is unavailable.
- `/media` is scratch space in this deployment and is not treated as a primary restore artifact.
- Mosquitto and MQTT Explorer are part of the namespace but are not restored by the Home Assistant native backup itself.

## Validation

After restore, verify:

- Home Assistant starts cleanly
- dashboards and automations are present
- integrations reconnect
- Zigbee/Z-Wave radios, if moved to replacement hardware, are reattached before restore
- add-ons and app-managed settings come back as expected
