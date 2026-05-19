#!/bin/sh
set -eu

timestamp_utc() {
  date -u +"%Y%m%d-%H%M%S"
}

require_env() {
  name="$1"
  value="$(printenv "$name" 2>/dev/null || true)"
  if [ -z "$value" ]; then
    echo "required environment variable missing: ${name}" >&2
    exit 1
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

prune_keep_count() {
  dir="$1"
  glob="$2"
  keep="$3"

  if [ ! -d "$dir" ]; then
    return 0
  fi

  find "$dir" -maxdepth 1 -type f -name "$glob" -printf '%P\n' \
    | sort -r \
    | awk -v keep="$keep" 'NR > keep { print }' \
    | while IFS= read -r file; do
        [ -n "$file" ] && rm -f "$dir/$file"
      done
}

write_metadata() {
  path="$1"
  app="$2"
  kind="$3"
  artifact="$4"

  cat >"$path" <<EOF
app=${app}
kind=${kind}
artifact=${artifact}
timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
node=$(hostname)
EOF
}
