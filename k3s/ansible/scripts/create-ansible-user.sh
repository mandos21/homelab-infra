#!/usr/bin/env bash
set -euo pipefail

ANSIBLE_USER="${ANSIBLE_USER:-ansible}"
AUTHORIZED_KEYS_SOURCE="${AUTHORIZED_KEYS_SOURCE:-$HOME/.ssh/authorized_keys}"
SUDOERS_FILE="/etc/sudoers.d/90-${ANSIBLE_USER}"

usage() {
  cat <<'EOF'
Usage: create-ansible-user.sh [--user ansible] [--authorized-keys /path/to/authorized_keys]

Creates a dedicated automation user with:
- a home directory
- bash shell
- membership in the sudo group
- passwordless sudo
- authorized_keys copied from the invoking user's authorized_keys by default

Environment variables:
- ANSIBLE_USER
- AUTHORIZED_KEYS_SOURCE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      ANSIBLE_USER="$2"
      shift 2
      ;;
    --authorized-keys)
      AUTHORIZED_KEYS_SOURCE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$AUTHORIZED_KEYS_SOURCE" ]]; then
  echo "authorized_keys source not found: $AUTHORIZED_KEYS_SOURCE" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required on the target host." >&2
  exit 1
fi

if ! command -v visudo >/dev/null 2>&1; then
  echo "visudo is required on the target host." >&2
  exit 1
fi

if id "$ANSIBLE_USER" >/dev/null 2>&1; then
  echo "User $ANSIBLE_USER already exists; updating SSH keys and sudoers."
else
  sudo useradd -m -s /bin/bash "$ANSIBLE_USER"
fi

sudo usermod -aG sudo "$ANSIBLE_USER"
sudo install -d -m 700 -o "$ANSIBLE_USER" -g "$ANSIBLE_USER" "/home/$ANSIBLE_USER/.ssh"
sudo install -m 600 -o "$ANSIBLE_USER" -g "$ANSIBLE_USER" "$AUTHORIZED_KEYS_SOURCE" "/home/$ANSIBLE_USER/.ssh/authorized_keys"

tmp_sudoers="$(mktemp)"
trap 'rm -f "$tmp_sudoers"' EXIT
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$ANSIBLE_USER" >"$tmp_sudoers"
sudo install -m 440 -o root -g root "$tmp_sudoers" "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE"

echo
echo "Created/updated $ANSIBLE_USER."
echo "Test with:"
echo "  ssh ${ANSIBLE_USER}@$(hostname -I | awk '{print $1}')"
