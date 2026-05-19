#!/bin/sh
set -eu
. /scripts/common.sh

require_env BACKUP_ROOT
require_env MATTERMOST_APP_NAME
require_env MATTERMOST_MMCTL_KEEP

backup_dir="${BACKUP_ROOT}/apps/${MATTERMOST_APP_NAME}/exports"
ensure_dir "$backup_dir"

stamp="$(timestamp_utc)"
final_zip="mattermost-mmctl-export-${stamp}.zip"
final_path="${backup_dir}/${final_zip}"
meta_file="${backup_dir}/mattermost-mmctl-export-${stamp}.meta"

pod_name="$(kubectl get pod -n mattermost -l app.kubernetes.io/name=mattermost -o jsonpath='{.items[0].metadata.name}')"
if [ -z "$pod_name" ]; then
  echo "failed to locate running Mattermost pod" >&2
  exit 1
fi

list_exports() {
  kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local --json export list 2>/dev/null || true
}

list_export_jobs() {
  kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local --json export job list 2>/dev/null || true
}

compact_json() {
  tr -d '\n\r\t '
}

extract_job_ids() {
  compact_json | sed -n 's/.*"id":"\([^"]*\)".*/\1/p'
}

list_export_names() {
  compact_json | sed 's/^\[//; s/\]$//' | tr ',' '\n' | sed 's/^"//; s/"$//' | sed '/^$/d'
}

extract_statuses() {
  compact_json | sed -n 's/.*"status":"\([^"]*\)".*/\1/p'
}

extract_active_job_ids() {
  compact_json \
    | sed 's/^\[//; s/\]$//; s/},{/}\n{/g' \
    | while IFS= read -r obj; do
        [ -z "$obj" ] && continue
        id="$(printf '%s\n' "$obj" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
        status="$(printf '%s\n' "$obj" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
        case "$status" in
          pending|in_progress|inprogress|started|cancel_requested)
            [ -n "$id" ] && printf '%s\n' "$id"
            ;;
        esac
      done
}

create_file="$(mktemp)"
jobs_file="$(mktemp)"
trap 'rm -f "$create_file" "$jobs_file"' EXIT

list_export_jobs > "$jobs_file" || true
active_job_ids="$(extract_active_job_ids < "$jobs_file" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
if [ -n "$active_job_ids" ]; then
  echo "refusing to start a new Mattermost export while export job(s) are active: $active_job_ids" >&2
  exit 1
fi

if ! kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local --json export create --include-archived-channels --include-profile-pictures > "$create_file" 2>&1; then
  echo "failed to start Mattermost export job" >&2
  cat "$create_file" >&2
  exit 1
fi
job_id="$(extract_job_ids < "$create_file" | head -n1)"

if [ -z "$job_id" ]; then
  echo "failed to parse Mattermost export job id" >&2
  cat "$create_file" >&2
  exit 1
fi

while true; do
  status_json="$(kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local --json export job show "$job_id")"
  status="$(printf '%s\n' "$status_json" | extract_statuses | head -n1)"
  case "$status" in
    success)
      break
      ;;
    pending|in_progress|inprogress|started|cancel_requested)
      sleep 15
      ;;
    *)
      echo "Mattermost export job ${job_id} failed with status: ${status}" >&2
      printf '%s\n' "$status_json" >&2
      exit 1
      ;;
  esac
done

export_name="${job_id}_export.zip"

if [ -z "$export_name" ]; then
  echo "failed to determine Mattermost export artifact name" >&2
  exit 1
fi

exports_now="$(list_exports | list_export_names || true)"
if ! printf '%s\n' "$exports_now" | grep -Fxq "$export_name"; then
  echo "expected Mattermost export artifact was not present in export list: ${export_name}" >&2
  printf 'available_exports=%s\n' "$(printf '%s' "$exports_now" | tr '\n' ' ' | sed 's/[[:space:]]*$//')" >&2
  exit 1
fi

if ! kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local export download "$export_name" "$final_path" >/dev/null 2>&1; then
  echo "failed to download Mattermost export artifact: ${export_name}" >&2
  printf 'job_id=%s\n' "$job_id" >&2
  printf 'hint=%s\n' "expected export artifact name derived from job id" >&2
  exit 1
fi
kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local export delete "$export_name" >/dev/null || true

chmod 0600 "$final_path"
write_metadata "$meta_file" "$MATTERMOST_APP_NAME" "mmctl-export" "$final_zip"
prune_keep_count "$backup_dir" 'mattermost-mmctl-export-*.zip' "$MATTERMOST_MMCTL_KEEP"
prune_keep_count "$backup_dir" 'mattermost-mmctl-export-*.meta' "$MATTERMOST_MMCTL_KEEP"
