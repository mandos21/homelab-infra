#!/bin/sh
set -eu
. /scripts/common.sh

require_env BACKUP_ROOT
require_env KEYCLOAK_APP_NAME
require_env KEYCLOAK_POSTGRES_HOST
require_env KEYCLOAK_POSTGRES_PORT
require_env KEYCLOAK_POSTGRES_DB
require_env KEYCLOAK_POSTGRES_USER
require_env KEYCLOAK_POSTGRES_PASSWORD
require_env KEYCLOAK_PGDUMP_KEEP

backup_dir="${BACKUP_ROOT}/apps/${KEYCLOAK_APP_NAME}/database/postgres"
ensure_dir "$backup_dir"

stamp="$(timestamp_utc)"
dump_file="${backup_dir}/keycloak-postgres-${stamp}.dump"
meta_file="${backup_dir}/keycloak-postgres-${stamp}.meta"

export PGPASSWORD="${KEYCLOAK_POSTGRES_PASSWORD}"
pg_dump \
  --host="${KEYCLOAK_POSTGRES_HOST}" \
  --port="${KEYCLOAK_POSTGRES_PORT}" \
  --username="${KEYCLOAK_POSTGRES_USER}" \
  --dbname="${KEYCLOAK_POSTGRES_DB}" \
  --format=custom \
  --file="${dump_file}"

chmod 0600 "${dump_file}"
write_metadata "${meta_file}" "${KEYCLOAK_APP_NAME}" "postgres-dump" "$(basename "${dump_file}")"
prune_keep_count "${backup_dir}" 'keycloak-postgres-*.dump' "${KEYCLOAK_PGDUMP_KEEP}"
prune_keep_count "${backup_dir}" 'keycloak-postgres-*.meta' "${KEYCLOAK_PGDUMP_KEEP}"
