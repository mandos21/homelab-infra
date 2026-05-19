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

extract_names() {
  sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | sort -u
}

extract_job_ids() {
  sed -n 's/.*"id":[[:space:]]*"\([^"]*\)".*/\1/p'
}

extract_active_job_ids() {
  awk '
    BEGIN {
      RS="}";
    }
    {
      id = "";
      status = "";
      if (match($0, /"id":[[:space:]]*"[^"]*"/)) {
        id = substr($0, RSTART, RLENGTH);
        sub(/^.*"id":[[:space:]]*"/, "", id);
        sub(/".*$/, "", id);
      }
      if (match($0, /"status":[[:space:]]*"[^"]*"/)) {
        status = substr($0, RSTART, RLENGTH);
        sub(/^.*"status":[[:space:]]*"/, "", status);
        sub(/".*$/, "", status);
      }
      if (id != "" && status ~ /^(pending|in_progress|inprogress|started|cancel_requested)$/) {
        print id;
      }
    }
  '
}

before_file="$(mktemp)"
after_file="$(mktemp)"
create_file="$(mktemp)"
jobs_file="$(mktemp)"
trap 'rm -f "$before_file" "$after_file" "$create_file" "$jobs_file"' EXIT

list_export_jobs > "$jobs_file" || true
active_job_ids="$(extract_active_job_ids < "$jobs_file" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
if [ -n "$active_job_ids" ]; then
  echo "refusing to start a new Mattermost export while export job(s) are active: $active_job_ids" >&2
  exit 1
fi

list_exports | extract_names > "$before_file" || true
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
  status="$(printf '%s' "$status_json" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -n1)"
  case "$status" in
    success)
      break
      ;;
    pending|in_progress|inprogress|started)
      sleep 15
      ;;
    *)
      echo "Mattermost export job ${job_id} failed with status: ${status}" >&2
      printf '%s\n' "$status_json" >&2
      exit 1
      ;;
  esac
done

list_exports | extract_names > "$after_file" || true
export_name="$(comm -13 "$before_file" "$after_file" | head -n1 || true)"
if [ -z "$export_name" ]; then
  export_name="$(tail -n1 "$after_file" || true)"
fi

if [ -z "$export_name" ]; then
  echo "failed to determine Mattermost export artifact name" >&2
  exit 1
fi

kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local export download "$export_name" "$final_path" >/dev/null
kubectl exec -n mattermost "$pod_name" -- /mattermost/bin/mmctl --local export delete "$export_name" >/dev/null || true

chmod 0600 "$final_path"
write_metadata "$meta_file" "$MATTERMOST_APP_NAME" "mmctl-export" "$final_zip"
prune_keep_count "$backup_dir" 'mattermost-mmctl-export-*.zip' "$MATTERMOST_MMCTL_KEEP"
prune_keep_count "$backup_dir" 'mattermost-mmctl-export-*.meta' "$MATTERMOST_MMCTL_KEEP"
