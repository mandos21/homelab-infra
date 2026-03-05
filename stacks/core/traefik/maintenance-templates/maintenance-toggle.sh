#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../../.." && pwd)
TEMPLATE="${SCRIPT_DIR}/maintenance-template.yml"
DYNAMIC_DIR="${TRAEFIK_DYNAMIC_DIR:-/mnt/user/appdata/traefik/dynamic}"

usage() {
  cat <<'USAGE'
Usage:
  maintenance-toggle.sh list
  maintenance-toggle.sh enable <service>
  maintenance-toggle.sh disable <service>

Notes:
- Valid services are derived from traefik router rules in docker-compose.yml files.
- Set TRAEFIK_DYNAMIC_DIR to override the destination directory.
USAGE
}

list_services() {
  python3 - <<PY
import re
from pathlib import Path

root = Path("${REPO_ROOT}")
pattern = re.compile(r"traefik\.http\.routers\.([^\.\s]+)\.rule")
host_re = re.compile(r"Host\(`([^`]+)`\)")
services = set()
for path in root.rglob("docker-compose.yml"):
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        continue
    for line in text.splitlines():
        m = pattern.search(line)
        if not m:
            continue
        if not host_re.search(line):
            continue
        services.add(m.group(1))

for name in sorted(services):
    print(name)
PY
}

get_host_for_service() {
  local service="$1"
  python3 - <<PY
import re
from pathlib import Path

root = Path("${REPO_ROOT}")
pattern = re.compile(r"traefik\.http\.routers\.([^\.\s]+)\.rule")
host_re = re.compile(r"Host\(`([^`]+)`\)")

wanted = "${service}"
for path in root.rglob("docker-compose.yml"):
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        continue
    for line in text.splitlines():
        m = pattern.search(line)
        if not m:
            continue
        if m.group(1) != wanted:
            continue
        hosts = host_re.findall(line)
        if hosts:
            print(hosts[0])
            raise SystemExit(0)

raise SystemExit(1)
PY
}

cmd="${1:-}"
case "${cmd}" in
  list)
    list_services
    ;;
  enable|disable)
    service="${2:-}"
    if [[ -z "${service}" ]]; then
      usage
      exit 1
    fi

    if ! list_services | grep -qx "${service}"; then
      echo "Invalid service: ${service}" >&2
      echo "Run: maintenance-toggle.sh list" >&2
      exit 1
    fi

    host=$(get_host_for_service "${service}")
    target="${DYNAMIC_DIR}/maintenance-${service}.yml"

    if [[ "${cmd}" == "disable" ]]; then
      rm -f "${target}"
      echo "Disabled maintenance for ${service}"
      exit 0
    fi

    mkdir -p "${DYNAMIC_DIR}"
    sed \
      -e "s/REPLACE_SERVER/${service}/g" \
      -e "s/REPLACE_HOST/${host}/g" \
      "${TEMPLATE}" > "${target}"

    echo "Enabled maintenance for ${service} (${host})"
    ;;
  *)
    usage
    exit 1
    ;;
esac
