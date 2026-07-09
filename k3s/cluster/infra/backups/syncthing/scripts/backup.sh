#!/bin/sh
set -eu
. /scripts/common.sh

require_env BACKUP_ROOT
require_env SYNCTHING_APP_NAME
require_env SYNCTHING_NAMESPACE
require_env SYNCTHING_FOLDER_PATH
require_env SYNCTHING_KEEP

backup_dir="${BACKUP_ROOT}/apps/${SYNCTHING_APP_NAME}/files/logseq"
ensure_dir "$backup_dir"

stamp="$(timestamp_utc)"
archive="${backup_dir}/logseq-graph-${stamp}.tar.gz"
meta="${backup_dir}/logseq-graph-${stamp}.meta"

syncthing_pod="$(kubectl get pod -n "$SYNCTHING_NAMESPACE" -l app.kubernetes.io/name=syncthing,app.kubernetes.io/component=app -o jsonpath='{.items[0].metadata.name}')"

if [ -z "$syncthing_pod" ]; then
  echo "failed to locate running Syncthing pod" >&2
  exit 1
fi

kubectl exec -n "$SYNCTHING_NAMESPACE" "$syncthing_pod" -- /bin/tar -C "$SYNCTHING_FOLDER_PATH" -cf - . | gzip -c > "$archive"

chmod 0600 "$archive"
write_metadata "$meta" "$SYNCTHING_APP_NAME" "logseq-graph-archive" "$(basename "$archive")"
prune_keep_count "$backup_dir" 'logseq-graph-*.tar.gz' "$SYNCTHING_KEEP"
prune_keep_count "$backup_dir" 'logseq-graph-*.meta' "$SYNCTHING_KEEP"

