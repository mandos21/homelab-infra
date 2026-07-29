# Unraid Exporter

Small Prometheus exporter for Unraid's GraphQL API.

## Configuration

- `UNRAID_GRAPHQL_URL`: Unraid GraphQL endpoint, for example `http://192.168.1.231/graphql`
- `UNRAID_API_KEY`: Unraid API key passed as the `x-api-key` header
- `LISTEN_ADDR`: exporter listen address, default `:9108`
- `SCRAPE_TIMEOUT`: GraphQL request timeout, default `10s`
- `UNRAID_TLS_SKIP_VERIFY`: set to `true` for internal Unraid HTTPS certificates that do not match the IP endpoint

## Build

```bash
docker build -t ghcr.io/mandos21/unraid-exporter:v0.1.0 tools/unraid-exporter
docker push ghcr.io/mandos21/unraid-exporter:v0.1.0
```

## Local Run

```bash
UNRAID_GRAPHQL_URL=http://192.168.1.231/graphql \
UNRAID_API_KEY=replace-me \
go run ./tools/unraid-exporter
```
