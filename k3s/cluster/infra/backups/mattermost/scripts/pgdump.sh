#!/bin/sh
set -eu
source /scripts/common.sh

require_env BACKUP_ROOT
require_env MATTERMOST_APP_NAME
require_env MATTERMOST_POSTGRES_HOST
require_env MATTERMOST_POSTGRES_PORT
require_env MATTERMOST_POSTGRES_DB
require_env MATTERMOST_POSTGRES_USER
require_env MATTERMOST_POSTGRES_PASSWORD
require_env MATTERMOST_PGDUMP_KEEP

backup_dir="${BACKUP_ROOT}/apps/${MATTERMOST_APP_NAME}/database/postgres"
ensure_dir "$backup_dir"

stamp="$(timestamp_utc)"
dump_file="${backup_dir}/mattermost-postgres-${stamp}.dump"
meta_file="${backup_dir}/mattermost-postgres-${stamp}.meta"

export PGPASSWORD="${MATTERMOST_POSTGRES_PASSWORD}"
pg_dump \
  --host="${MATTERMOST_POSTGRES_HOST}" \
  --port="${MATTERMOST_POSTGRES_PORT}" \
  --username="${MATTERMOST_POSTGRES_USER}" \
  --dbname="${MATTERMOST_POSTGRES_DB}" \
  --format=custom \
  --file="${dump_file}"

chmod 0600 "${dump_file}"
write_metadata "${meta_file}" "${MATTERMOST_APP_NAME}" "postgres-dump" "$(basename "${dump_file}")"
prune_keep_count "${backup_dir}" 'mattermost-postgres-*.dump' "${MATTERMOST_PGDUMP_KEEP}"
prune_keep_count "${backup_dir}" 'mattermost-postgres-*.meta' "${MATTERMOST_PGDUMP_KEEP}"
