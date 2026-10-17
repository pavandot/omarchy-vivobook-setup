#!/bin/bash
# Set the laptop panel's scale and add 1.33x / 1.5x to the Display panel, or undo it.
#
#   display-scaling.sh install [SCALE]   set the scale (default 1.33) and patch the
#                                        Display panel's scale buttons
#   display-scaling.sh revert            restore monitors.lua from before the first install and
#                                        go back to the stock Display panel
#   display-scaling.sh status            show the scale, the panel in use and text size
#
# Omarchy's Display panel only offers 1, 1.25, 1.6, 2, 3 and 4. The panel is
# cloned with `omarchy plugin clone` (a user copy that survives `omarchy update`)
# and its button list is replaced. Nothing under /usr/share/omarchy is changed.
# Must be run inside the Hyprland session.
set -euo pipefail

SCALE_DEFAULT=1.33
PRESETS='"1", "1.25", "1.33", "1.5", "1.6", "2"'

MONITORS_LUA=$HOME/.config/hypr/monitors.lua
SHELL_JSON=$HOME/.config/omarchy/shell.json
PANEL_ID=${USER:-$(id -un)}.monitor
PANEL_QML=$HOME/.config/omarchy/plugins/$PANEL_ID/Panel.qml
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-vivobook-setup/display-scaling
PRESETS_RE='^([[:space:]]*readonly property var scalePresets: )\[.*\]'

die() { echo "error: $*" >&2; exit 1; }

require_session() {
  command -v omarchy >/dev/null || die "omarchy not found: this fix is for Omarchy"
  hyprctl monitors -j >/dev/null 2>&1 || die "Hyprland is not reachable: run this inside the desktop session"
}

current_scale() { hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.name) \(.width)x\(.height) scale \(.scale)"'; }

patch_panel() {
  if [ ! -d "${PANEL_QML%/*}" ]; then
    mkdir -p "$STATE_DIR"
    [ -f "$SHELL_JSON" ] && cp "$SHELL_JSON" "$STATE_DIR/shell.json.$(date +%Y%m%d-%H%M%S)"
    omarchy plugin clone omarchy.monitor
  else
    echo "  $PANEL_ID already cloned, reusing it"
  fi
  grep -Eq "$PRESETS_RE" "$PANEL_QML" ||
    die "scalePresets line not found in $PANEL_QML (the panel changed upstream; edit it by hand)"
  sed -i -E "s/$PRESETS_RE/\1[$PRESETS]/" "$PANEL_QML"
  echo "  panel buttons: $(grep -Eo 'scalePresets: \[.*\]' "$PANEL_QML")"
}

install() {
  local scale=${1:-$SCALE_DEFAULT}
  require_session

  echo "Scale:"
  mkdir -p "$STATE_DIR"
  [ -f "$MONITORS_LUA" ] && cp "$MONITORS_LUA" "$STATE_DIR/monitors.lua.$(date +%Y%m%d-%H%M%S)"
  omarchy hyprland monitor scaling "$scale"
  echo "  $(current_scale)"

  echo "Display panel:"
  patch_panel

  # The shell's hot reload doesn't always swap a freshly cloned panel in; a
  # restart does.
  echo "Restarting the Omarchy shell..."
  omarchy restart shell >/dev/null 2>&1 || true
  echo "Done. Backups are in $STATE_DIR"
}

revert() {
  require_session
  local backup
  backup=$(find "$STATE_DIR" -maxdepth 1 -name 'monitors.lua.*' 2>/dev/null | sort | head -1)
  if [ -n "$backup" ]; then
    cp "$backup" "$MONITORS_LUA"
    hyprctl reload >/dev/null
    echo "Restored $MONITORS_LUA from $backup"
    echo "  $(current_scale)"
  else
    echo "No monitors.lua backup in $STATE_DIR; scale left as is"
  fi

  if [ -d "${PANEL_QML%/*}" ]; then
    omarchy plugin remove "$PANEL_ID" --yes
    omarchy restart shell >/dev/null 2>&1 || true
  else
    echo "$PANEL_ID not installed; already on the stock Display panel"
  fi
}

status() {
  require_session
  echo "Monitor:      $(current_scale)"
  echo "monitors.lua: $(grep -E '^local omarchy_(monitor|gdk)_scale' "$MONITORS_LUA" 2>/dev/null | tr '\n' ' ')"
  echo "Bar widget:   $(jq -r '.. | objects | .id? // empty | select(test("\\.monitor$"))' "$SHELL_JSON" 2>/dev/null | head -1)"
  if [ -f "$PANEL_QML" ]; then
    echo "Panel:        $(grep -Eo 'scalePresets: \[.*\]' "$PANEL_QML")"
  else
    echo "Panel:        stock omarchy.monitor (1, 1.25, 1.6, 2, 3, 4)"
  fi
  echo "Text size:"
  omarchy display text size | sed 's/^/  /'
}

case "${1:-}" in
  install) shift; install "$@" ;;
  revert) revert ;;
  status) status ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
