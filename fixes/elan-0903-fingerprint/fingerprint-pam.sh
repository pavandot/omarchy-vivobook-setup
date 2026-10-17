#!/bin/bash
# Enable fingerprint authentication in PAM with password fallback, or undo it.
#
#   fingerprint-pam.sh install         back up PAM files, add pam_fprintd
#   fingerprint-pam.sh revert          restore the files from the last backup
#   fingerprint-pam.sh status          show the driver, enrolled prints and PAM state
#   fingerprint-pam.sh test-fallback   prove password login still works in every
#                                      stack (uses a temporary user, then deletes it)
#
# pam_fprintd is added as "sufficient" before the normal password stack, so a
# failed/absent fingerprint always falls through to the password. On Omarchy the
# lid-closed gate is added (skip fingerprint when the lid is shut) and the lock
# screen's omarchy-lock-fingerprint service is created; the lock screen's
# password path is left untouched.
#
# PAM_DIR, VENDOR_PAM_DIR and STATE_DIR can be overridden for testing.
set -euo pipefail

PAM_DIR=${PAM_DIR:-/etc/pam.d}
VENDOR_PAM_DIR=${VENDOR_PAM_DIR:-/usr/lib/pam.d}
STATE_DIR=${STATE_DIR:-/var/lib/fingerprint-pam}
FILES=(sudo polkit-1 login omarchy-lock-fingerprint)

FP='auth      sufficient pam_fprintd.so max-tries=3 timeout=20'
GATE_CMD=/usr/bin/omarchy-hw-laptop-closed
GATE="auth      [success=1 default=ignore] pam_exec.so quiet $GATE_CMD"

die() { echo "error: $*" >&2; exit 1; }
as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }

is_omarchy() { [ -x "$GATE_CMD" ] && [ -d /usr/share/omarchy ]; }

# insert the fingerprint lines into one PAM file, before its first auth line
# (or after pam_nologin for login); no-op if pam_fprintd is already there
add_fp() {
  local f=$PAM_DIR/$1 lines tmp
  if grep -q 'pam_fprintd\.so' "$f"; then
    echo "  $1: pam_fprintd already present, skipping"
    return
  fi
  lines=$FP
  is_omarchy && lines="$GATE"$'\n'"$FP"
  tmp=$(mktemp)
  awk -v ins="$lines" -v after_nologin="$([ "$1" = login ] && echo 1 || echo 0)" '
    !done && after_nologin == 1 && /pam_nologin\.so/ { print; print ins; done = 1; next }
    !done && after_nologin == 0 && /^[ \t]*-?auth[ \t]/ { print ins; done = 1 }
    { print }
    END { if (!done) exit 1 }' "$f" > "$tmp" || { rm -f "$tmp"; die "no auth line found in $f"; }
  as_root install -m 644 "$tmp" "$f"
  rm -f "$tmp"
  echo "  $1: added pam_fprintd$(is_omarchy && echo ' (with lid gate)')"
}

backup_pam() {
  local bk f
  bk=$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)
  as_root mkdir -p "$bk"
  for f in "${FILES[@]}"; do
    if [ -e "$PAM_DIR/$f" ]; then
      grep -q 'pam_fprintd\.so' "$PAM_DIR/$f" &&
        echo "warning: $f already uses pam_fprintd; the backup is not pristine" >&2
      as_root cp -a "$PAM_DIR/$f" "$bk/$f"
    else
      echo "$f" | as_root tee -a "$bk/ABSENT" >/dev/null
    fi
  done
  echo "$bk" | as_root tee "$STATE_DIR/last-backup" >/dev/null
  echo "Backed up PAM files to $bk"
}

cmd_install() {
  command -v fprintd-list >/dev/null || die "fprintd is not installed"
  [ -e /usr/lib/security/pam_fprintd.so ] || [ -n "${SKIP_MODULE_CHECK:-}" ] ||
    die "pam_fprintd.so not found (install fprintd)"

  local bk
  # keep the first (pristine) backup across repeated installs; revert clears it
  if bk=$(cat "$STATE_DIR/last-backup" 2>/dev/null) && [ -d "$bk" ]; then
    echo "Keeping existing backup $bk"
  else
    backup_pam
  fi

  add_fp sudo
  add_fp login
  if [ ! -e "$PAM_DIR/polkit-1" ]; then
    [ -e "$VENDOR_PAM_DIR/polkit-1" ] || die "no polkit-1 PAM file to start from"
    as_root install -m 644 "$VENDOR_PAM_DIR/polkit-1" "$PAM_DIR/polkit-1"
  fi
  add_fp polkit-1

  if is_omarchy; then
    as_root tee "$PAM_DIR/omarchy-lock-fingerprint" >/dev/null <<'EOF'
#%PAM-1.0
auth       required                    pam_fprintd.so
account    include                     system-local-login
EOF
    echo "  omarchy-lock-fingerprint: written (lock screen fingerprint)"
  fi
  echo "Done. Revert with: $0 revert"
}

cmd_revert() {
  local bk
  bk=$(cat "$STATE_DIR/last-backup" 2>/dev/null) || die "no backup recorded in $STATE_DIR"
  [ -d "$bk" ] || die "backup $bk is missing"
  for f in "${FILES[@]}"; do
    if [ -e "$bk/$f" ]; then
      as_root cp -a "$bk/$f" "$PAM_DIR/$f"
      echo "  $f: restored"
    elif grep -qx "$f" "$bk/ABSENT" 2>/dev/null; then
      as_root rm -f "$PAM_DIR/$f"
      echo "  $f: removed (did not exist before)"
    fi
  done
  as_root rm -f "$STATE_DIR/last-backup"
  echo "PAM restored from $bk (backup kept)"
}

cmd_status() {
  echo "== packages";  pacman -Q 2>/dev/null | grep -E 'fprint' || true
  echo "== library";   ldd /usr/lib/libfprint-2.so.2 2>/dev/null | grep -E 'not found|opencv' | head -3 || true
  echo "== device";    fprintd-list "${SUDO_USER:-$USER}" 2>&1 | sed -n '1,6p' || true
  echo "== pam"
  for f in "${FILES[@]}"; do
    if [ -e "$PAM_DIR/$f" ]; then
      printf '  %-26s %s\n' "$f" "$(grep -q pam_fprintd "$PAM_DIR/$f" && echo fingerprint || echo 'password only')"
    else
      printf '  %-26s %s\n' "$f" "absent"
    fi
  done
}

cmd_test_fallback() {
  local here dir user=fpfallbacktest pw rc=0 svc
  here=$(cd "$(dirname "$0")" && pwd)
  dir=$(mktemp -d)
  pw="Tmp-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  gcc -o "$dir/pamtest" "$here/pamtest.c" -lpam || die "building pamtest failed (needs gcc and pam headers)"
  id "$user" >/dev/null 2>&1 && die "user $user already exists"
  as_root useradd -M -s /bin/bash "$user"
  trap 'as_root faillock --user '"$user"' --reset >/dev/null 2>&1; as_root userdel '"$user"' >/dev/null 2>&1; rm -rf '"$dir"'' EXIT
  echo "$user:$pw" | as_root chpasswd
  for svc in sudo polkit-1 login omarchy-lock-password; do
    [ -e "$PAM_DIR/$svc" ] || [ -e "$VENDOR_PAM_DIR/$svc" ] || continue
    if as_root "$dir/pamtest" "$svc" "$user" "$pw" >/dev/null 2>&1 &&
       ! as_root "$dir/pamtest" "$svc" "$user" wrong-password >/dev/null 2>&1; then
      echo "  $svc: password fallback OK (right password accepted, wrong rejected)"
    else
      echo "  $svc: PASSWORD FALLBACK BROKEN - revert now"; rc=1
    fi
  done
  return $rc
}

case "${1:-}" in
  install) cmd_install ;;
  revert) cmd_revert ;;
  status) cmd_status ;;
  test-fallback) cmd_test_fallback ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
