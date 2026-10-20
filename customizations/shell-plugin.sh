#!/usr/bin/env bash
# Install, revert or check one of the Omarchy shell plugin clones kept in this repo.
#
#   ./shell-plugin.sh install <plugin-dir>   copy into ~/.config/omarchy/plugins and enable
#   ./shell-plugin.sh revert  <plugin-dir>   remove the clone; Omarchy's original comes back
#   ./shell-plugin.sh status  <plugin-dir>   show which of the two is enabled
#
# <plugin-dir> is a folder holding a manifest.json, e.g. notifications-close-button/pavan.notifications
set -euo pipefail

die() { echo "shell-plugin.sh: $*" >&2; exit 1; }

action="${1:-}"
src="${2:-}"
[[ -n $action && -n $src ]] || die "usage: $0 install|revert|status <plugin-dir>"
[[ -f $src/manifest.json ]] || die "$src has no manifest.json"
command -v jq >/dev/null || die "jq is required"

id=$(jq -r '.id' "$src/manifest.json")
original=$(jq -r '.omarchy.clonedFrom // empty' "$src/manifest.json")
dest="$HOME/.config/omarchy/plugins/$id"

enabled() {
  omarchy plugin list --json | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

case "$action" in
  install)
    if [[ -e $dest ]]; then
      # Keep the existing copy where the shell won't discover it: dot-prefixed,
      # like `omarchy plugin remove` does, so the ids don't clash.
      backup="$HOME/.config/omarchy/plugins/.${id}.bak.$(date -u +%Y%m%d%H%M%S)"
      mv -- "$dest" "$backup"
      echo "Backed up the existing $id to $backup"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a -- "$src" "$dest"
    omarchy-shell shell rescanPlugins >/dev/null
    # Enabling a clone disables the plugin it was cloned from.
    omarchy plugin enable "$id" >/dev/null
    if [[ -n $original ]] && enabled "$original"; then
      omarchy plugin disable "$original" >/dev/null
    fi
    # Service plugins register IPC handlers and the polkit agent at startup,
    # so the original keeps them until the shell restarts.
    omarchy restart shell >/dev/null 2>&1 || true
    echo "Installed and enabled $id${original:+ (replacing $original)}."
    ;;
  revert)
    [[ -e $dest ]] || die "$id is not installed"
    omarchy plugin remove "$id" --yes
    if [[ -n $original ]] && ! enabled "$original"; then
      omarchy plugin enable "$original" >/dev/null
    fi
    omarchy restart shell >/dev/null 2>&1 || true
    echo "Reverted to ${original:-the default}."
    ;;
  status)
    for p in "$id" ${original:+"$original"}; do
      if enabled "$p"; then echo "$p: enabled"; else echo "$p: disabled or not installed"; fi
    done
    if [[ -d $dest ]] && diff -rq -- "$src" "$dest" >/dev/null; then
      echo "Installed copy matches this repo."
    elif [[ -d $dest ]]; then
      echo "Installed copy differs from this repo."
    fi
    ;;
  *)
    die "unknown action: $action"
    ;;
esac
