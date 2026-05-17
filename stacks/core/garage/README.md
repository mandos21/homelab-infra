# Garage on Unraid

This is a single-node Garage deployment for use as a local S3-compatible backup target for:

- `k3s etcd` snapshots
- `Longhorn` recurring backups

It uses the official `dxflrs/garage` image and an Unraid Docker template instead of Compose.

The template explicitly pins the entrypoint to `/garage` and uses post arguments:

- `server`

The official image reads its config from `/etc/garage.toml`, so the template mounts the config file directly there instead of passing a `--config` flag.
Unraid is not preserving the image entrypoint correctly here, so the explicit `--entrypoint /garage` is required.

## Files

- `stacks/core/garage/my-garage.xml`
  Unraid Docker template
- `stacks/core/garage/my-garage-webui.xml`
  Unraid Docker template for the Garage Web UI
- `stacks/core/garage/garage.toml.example`
  starter config file

## Recommended host paths

- config file: `/mnt/user/appdata/garage/config/garage.toml`
- metadata: `/mnt/user/appdata/garage/meta`
- data: `/mnt/user/backups/garage/data`

Why:

- config and metadata are small and operationally important
- object data is backup payload, so it belongs under `/mnt/user/backups`

## Unraid install steps

1. Create directories:

```bash
mkdir -p /mnt/user/appdata/garage/config
mkdir -p /mnt/user/appdata/garage/meta
mkdir -p /mnt/user/backups/garage/data
```

2. Copy `stacks/core/garage/my-garage.xml` to:

```bash
/boot/config/plugins/dockerMan/templates-user/my-garage.xml
```

If you also want the Web UI, copy:

```bash
/boot/config/plugins/dockerMan/templates-user/my-garage-webui.xml
```

3. Copy `stacks/core/garage/garage.toml.example` to:

```bash
/mnt/user/appdata/garage/config/garage.toml
```

4. Edit `garage.toml` and replace:

- `192.168.1.231` with your Unraid LAN IP if different
- `CHANGE_ME_RPC_SECRET`
- `CHANGE_ME_ADMIN_TOKEN`

Generate secrets like this:

```bash
openssl rand -hex 32
openssl rand -base64 32
```

5. In Unraid:

- `Docker`
- `Add Container`
- select template: `Garage`
- confirm the paths and ports
- deploy

## Networking

This template uses `bridge` mode with published ports.

Published ports:

- `3900/tcp` S3 API
- `3901/tcp` Garage RPC
- `3903/tcp` Admin API

`3902` for `s3_web` is included as an optional advanced port. You do not need it for `etcd` or `Longhorn`.

## First-start commands

Run inside Unraid after the container is up:

```bash
docker exec -it Garage /garage -c /etc/garage.toml status
docker exec -it Garage /garage -c /etc/garage.toml node id
docker exec -it Garage /garage -c /etc/garage.toml layout assign -z unraid -c 500G $(docker exec Garage /garage -c /etc/garage.toml node id -q | cut -d@ -f1)
docker exec -it Garage /garage -c /etc/garage.toml layout apply --version 1
docker exec -it Garage /garage bucket create homelab-etcd
docker exec -it Garage /garage bucket create homelab-longhorn
docker exec -it Garage /garage key create homelab-etcd
docker exec -it Garage /garage key create homelab-longhorn
```

Then grant bucket access:

```bash
docker exec -it Garage /garage bucket allow --read --write homelab-etcd --key homelab-etcd
docker exec -it Garage /garage bucket allow --read --write homelab-longhorn --key homelab-longhorn
```

Then inspect the generated access/secret keys:

```bash
docker exec -it Garage /garage key info homelab-etcd
docker exec -it Garage /garage key info homelab-longhorn
```

## Notes

- This is intentionally single-node and uses `replication_factor = 1`.
- That is acceptable for a local landing zone, but not your only meaningful copy.
- Offsite replication still matters later.
- If you later see networking weirdness in bridge mode, the official docs prefer `host` mode on Linux.

## Garage Web UI

The Web UI template uses:

- image: `khairul169/garage-webui:latest`
- mounted config file: `/etc/garage.toml`
- default UI port: `3909`

Recommended environment values:

- `CONFIG_PATH`
  default: `/etc/garage.toml`
- optionally `API_BASE_URL`
  example: `http://192.168.1.231:3903`
- optionally `S3_ENDPOINT_URL`
  example: `http://192.168.1.231:3900`
- optionally `S3_REGION`
  example: `garage`

Authentication is optional. If you enable it:

- `AUTH_USER_PASS`
  format: `username:bcrypt_hash`

Generate the bcrypt hash with:

```bash
htpasswd -nbBC 10 YOUR_USERNAME YOUR_PASSWORD
```

If the UI fails to load values from `garage.toml`, you can also set:

- `API_ADMIN_KEY`

The Web UI can read values like `rpc_public_addr`, `admin_token`, and S3 settings from `garage.toml`. The explicit environment values are there as overrides/fallbacks.
