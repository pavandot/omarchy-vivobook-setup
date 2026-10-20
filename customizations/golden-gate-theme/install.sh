#!/usr/bin/env bash
# Golden Gate theme: macOS 27 "Golden Gate" dark mode for Omarchy.
#
#   ./install.sh install [--apple-wallpapers]   copy the theme into ~/.config/omarchy/themes and apply it
#   ./install.sh revert                         go back to the theme you had before, remove Golden Gate
#   ./install.sh status
#
# Installed as a local theme (not with `omarchy theme install`), so its hyprland.lua
# is used directly: glass blur, shadows, 1px specular borders, 12px corners, 8px gaps.
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src="$here/golden-gate"
dest="$HOME/.config/omarchy/themes/golden-gate"
state="$HOME/.local/state/omarchy-vivobook-setup"
previous_file="$state/golden-gate-previous-theme"

die() { echo "install.sh: $*" >&2; exit 1; }

case "${1:-}" in
  install)
    mkdir -p "$state"
    current=$(omarchy theme current 2>/dev/null || true)
    if [[ -n $current && $current != "Golden Gate" ]]; then
      echo "$current" >"$previous_file"
    fi
    if [[ -e $dest ]]; then
      backup="$state/golden-gate.bak.$(date -u +%Y%m%d%H%M%S)"
      mv -- "$dest" "$backup"
      echo "Backed up the existing theme to $backup"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a -- "$src" "$dest"
    omarchy theme set golden-gate
    if [[ ${2:-} == "--apple-wallpapers" ]]; then
      "$dest/extras/get-apple-wallpapers.sh"
    fi
    errors=$(hyprctl configerrors 2>/dev/null || true)
    [[ -z ${errors//[[:space:]]/} ]] || { echo "$errors" >&2; die "Hyprland reported config errors"; }
    echo "Golden Gate installed and applied."
    ;;
  revert)
    previous=$(cat "$previous_file" 2>/dev/null || true)
    if [[ $(omarchy theme current 2>/dev/null) == "Golden Gate" ]]; then
      [[ -n $previous ]] || die "no previous theme recorded; run: omarchy theme set <name>, then rerun revert"
      omarchy theme set "$previous"
    fi
    [[ -e $dest ]] && mv -- "$dest" "$state/golden-gate.removed.$(date -u +%Y%m%d%H%M%S)"
    echo "Reverted${previous:+ to $previous}. Apple wallpapers, if fetched, stay in ~/.config/omarchy/backgrounds/golden-gate/."
    ;;
  status)
    echo "Current theme: $(omarchy theme current 2>/dev/null || echo unknown)"
    if [[ -d $dest ]] && diff -rq -- "$src" "$dest" >/dev/null; then
      echo "Installed copy matches this repo."
    elif [[ -d $dest ]]; then
      echo "Installed copy differs from this repo:"; diff -rq -- "$src" "$dest" || true
    else
      echo "Not installed."
    fi
    ;;
  *)
    die "usage: $0 install [--apple-wallpapers] | revert | status"
    ;;
esac
