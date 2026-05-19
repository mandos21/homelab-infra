#!/bin/sh
set -eu
source /scripts/common.sh

require_env BACKUP_ROOT
require_env NEXTCLOUD_APP_NAME
require_env NEXTCLOUD_DB_HOST
require_env NEXTCLOUD_DB_NAME
require_env NEXTCLOUD_MYSQL_ROOT_PASSWORD
require_env NEXTCLOUD_DB_KEEP
require_env NEXTCLOUD_CONFIG_KEEP

db_dir="${BACKUP_ROOT}/apps/${NEXTCLOUD_APP_NAME}/database/mariadb"
config_dir="${BACKUP_ROOT}/apps/${NEXTCLOUD_APP_NAME}/files/config"
meta_dir="${BACKUP_ROOT}/apps/${NEXTCLOUD_APP_NAME}/metadata"
ensure_dir "$db_dir"
ensure_dir "$config_dir"
ensure_dir "$meta_dir"

stamp="$(timestamp_utc)"
db_file="${db_dir}/nextcloud-mariadb-${stamp}.sql.gz"
config_file="${config_dir}/nextcloud-config-${stamp}.tar.gz"
meta_file="${meta_dir}/nextcloud-maintenance-window-${stamp}.meta"

nextcloud_pod="$(kubectl get pod -n nextcloud -l app.kubernetes.io/name=nextcloud,app.kubernetes.io/component=app -o jsonpath='{.items[0].metadata.name}')"
mariadb_pod="$(kubectl get pod -n nextcloud -l app.kubernetes.io/name=mariadb,app.kubernetes.io/component=database -o jsonpath='{.items[0].metadata.name}')"

if [ -z "$nextcloud_pod" ] || [ -z "$mariadb_pod" ]; then
  echo "failed to locate running Nextcloud or MariaDB pod" >&2
  exit 1
fi

maintenance_off() {
  kubectl exec -n nextcloud "$nextcloud_pod" -- /bin/sh -lc 'php /app/www/public/occ maintenance:mode --off >/dev/null' >/dev/null 2>&1 || true
}
trap maintenance_off EXIT INT TERM

kubectl exec -n nextcloud "$nextcloud_pod" -- /bin/sh -lc 'php /app/www/public/occ maintenance:mode --on'

kubectl exec -n nextcloud "$mariadb_pod" -- /bin/sh -lc \
  "MYSQL_PWD='${NEXTCLOUD_MYSQL_ROOT_PASSWORD}' /usr/bin/mariadb-dump --single-transaction --routines --events --hex-blob -u root '${NEXTCLOUD_DB_NAME}'" \
  | gzip -c > "$db_file"

kubectl exec -n nextcloud "$nextcloud_pod" -- /bin/tar -C /config -cf - . | gzip -c > "$config_file"

cat >"$meta_file" <<EOF
app=nextcloud
kind=coordinated-maintenance-window
database_artifact=$(basename "$db_file")
config_artifact=$(basename "$config_file")
timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
node=$(hostname)
note=Capture Unraid snapshots of /mnt/user/nextData and /mnt/user/ebook_uploads during this maintenance window.
EOF

chmod 0600 "$db_file" "$config_file"
prune_keep_count "$db_dir" 'nextcloud-mariadb-*.sql.gz' "$NEXTCLOUD_DB_KEEP"
prune_keep_count "$config_dir" 'nextcloud-config-*.tar.gz' "$NEXTCLOUD_CONFIG_KEEP"
prune_keep_count "$meta_dir" 'nextcloud-maintenance-window-*.meta' "$NEXTCLOUD_CONFIG_KEEP"
