#!/usr/bin/env bash
# Validate the real role-specific settings parser without storage or Docker.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source <(sed -n '/^pgbackrest_cipher_config() {$/,/^}$/p' "$ROOT/wrapper.sh")
source <(sed -n '/^validate_pgbackrest_encryption() {$/,/^}$/p' "$ROOT/wrapper.sh")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
unset WAL_ARCHIVE_CIPHER_TYPE WAL_ARCHIVE_CIPHER_PASS WAL_RECOVER_FROM_CIPHER_TYPE WAL_RECOVER_FROM_CIPHER_PASS
test "$(pgbackrest_cipher_config WAL_ARCHIVE)" = repo1-cipher-type=none
test "$(pgbackrest_cipher_config WAL_RECOVER_FROM)" = repo1-cipher-type=none
export WAL_ARCHIVE_BUCKET=archive WAL_RECOVER_FROM_BUCKET=source
export WAL_ARCHIVE_CIPHER_TYPE=aes-256-cbc WAL_ARCHIVE_CIPHER_PASS=archive-test-key
export WAL_RECOVER_FROM_CIPHER_TYPE=aes-256-cbc WAL_RECOVER_FROM_CIPHER_PASS=recovery-test-key
validate_pgbackrest_encryption
pgbackrest_cipher_config WAL_ARCHIVE > "$WORK/archive"
pgbackrest_cipher_config WAL_RECOVER_FROM > "$WORK/recovery"
grep -qx 'repo1-cipher-pass=archive-test-key' "$WORK/archive"
grep -qx 'repo1-cipher-pass=recovery-test-key' "$WORK/recovery"
! grep -q archive-test-key "$WORK/recovery"
for role in WAL_ARCHIVE WAL_RECOVER_FROM; do
  for mode in missing invalid multiline disabled; do
    (
      export "${role}_CIPHER_TYPE=aes-256-cbc" "${role}_CIPHER_PASS=do-not-log-this-secret"
      case "$mode" in
        missing) export "${role}_CIPHER_PASS=" ;;
        invalid) export "${role}_CIPHER_TYPE=invalid" ;;
        multiline) export "${role}_CIPHER_PASS="$'do-not-log-this-secret\nrepo1-cipher-type=none' ;;
        disabled) export "${role}_CIPHER_TYPE=none" ;;
      esac
      if validate_pgbackrest_encryption > "$WORK/out" 2> "$WORK/err"; then
        echo "accepted invalid $role $mode settings" >&2
        exit 1
      fi
      ! grep -q do-not-log-this-secret "$WORK/out" "$WORK/err"
    )
  done
done
echo 'encryption defaults off; roles use independent keys; invalid settings refuse without logging secrets'
