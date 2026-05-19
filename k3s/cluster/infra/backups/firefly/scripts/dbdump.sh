#!/bin/sh
set -eu
. /scripts/common.sh

require_env BACKUP_ROOT
require_env FIREFLY_APP_NAME
require_env FIREFLY_DB_HOST
require_env FIREFLY_DB_PORT
require_env FIREFLY_DB_NAME
require_env FIREFLY_DB_USER
require_env FIREFLY_DB_PASSWORD
require_env FIREFLY_DB_KEEP

backup_dir="${BACKUP_ROOT}/apps/${FIREFLY_APP_NAME}/database/mariadb"
ensure_dir "$backup_dir"

stamp="$(timestamp_utc)"
dump_file="${backup_dir}/firefly-mariadb-${stamp}.sql.gz"
meta_file="${backup_dir}/firefly-mariadb-${stamp}.meta"

MYSQL_PWD="${FIREFLY_DB_PASSWORD}" \
mariadb-dump \
  --host="${FIREFLY_DB_HOST}" \
  --port="${FIREFLY_DB_PORT}" \
  --user="${FIREFLY_DB_USER}" \
  --single-transaction \
  --routines \
  --events \
  --hex-blob \
  "${FIREFLY_DB_NAME}" \
  | gzip -c > "${dump_file}"

chmod 0600 "${dump_file}"
write_metadata "${meta_file}" "${FIREFLY_APP_NAME}" "mariadb-dump" "$(basename "${dump_file}")"
prune_keep_count "${backup_dir}" 'firefly-mariadb-*.sql.gz' "${FIREFLY_DB_KEEP}"
prune_keep_count "${backup_dir}" 'firefly-mariadb-*.meta' "${FIREFLY_DB_KEEP}"
