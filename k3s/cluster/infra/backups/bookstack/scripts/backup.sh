#!/bin/sh
set -eu
. /scripts/common.sh

require_env BACKUP_ROOT
require_env BOOKSTACK_APP_NAME
require_env BOOKSTACK_DB_NAME
require_env BOOKSTACK_DB_ROOT_PASSWORD
require_env BOOKSTACK_DB_KEEP
require_env BOOKSTACK_CONFIG_KEEP

db_dir="${BACKUP_ROOT}/apps/${BOOKSTACK_APP_NAME}/database/mariadb"
config_dir="${BACKUP_ROOT}/apps/${BOOKSTACK_APP_NAME}/files/config"
ensure_dir "$db_dir"
ensure_dir "$config_dir"

stamp="$(timestamp_utc)"
db_file="${db_dir}/bookstack-mariadb-${stamp}.sql.gz"
db_meta="${db_dir}/bookstack-mariadb-${stamp}.meta"
config_file="${config_dir}/bookstack-config-${stamp}.tar.gz"
config_meta="${config_dir}/bookstack-config-${stamp}.meta"

bookstack_pod="$(kubectl get pod -n bookstack -l app.kubernetes.io/name=bookstack,app.kubernetes.io/component=app -o jsonpath='{.items[0].metadata.name}')"
mariadb_pod="$(kubectl get pod -n bookstack -l app.kubernetes.io/name=mariadb,app.kubernetes.io/component=database -o jsonpath='{.items[0].metadata.name}')"

if [ -z "$bookstack_pod" ] || [ -z "$mariadb_pod" ]; then
  echo "failed to locate running BookStack or MariaDB pod" >&2
  exit 1
fi

kubectl exec -n bookstack "$mariadb_pod" -- /bin/sh -lc \
  "MYSQL_PWD='${BOOKSTACK_DB_ROOT_PASSWORD}' /usr/bin/mariadb-dump --single-transaction --routines --events --hex-blob -u root '${BOOKSTACK_DB_NAME}'" \
  | gzip -c > "$db_file"

kubectl exec -n bookstack "$bookstack_pod" -- /bin/tar -C /config -cf - . | gzip -c > "$config_file"

chmod 0600 "$db_file" "$config_file"
write_metadata "$db_meta" "$BOOKSTACK_APP_NAME" "mariadb-dump" "$(basename "$db_file")"
write_metadata "$config_meta" "$BOOKSTACK_APP_NAME" "config-archive" "$(basename "$config_file")"
prune_keep_count "$db_dir" 'bookstack-mariadb-*.sql.gz' "$BOOKSTACK_DB_KEEP"
prune_keep_count "$db_dir" 'bookstack-mariadb-*.meta' "$BOOKSTACK_DB_KEEP"
prune_keep_count "$config_dir" 'bookstack-config-*.tar.gz' "$BOOKSTACK_CONFIG_KEEP"
prune_keep_count "$config_dir" 'bookstack-config-*.meta' "$BOOKSTACK_CONFIG_KEEP"
