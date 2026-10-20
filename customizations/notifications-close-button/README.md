# Notification close button

**Status:** ✅ working, verified 2026-10-20 on Omarchy 4.0.6 (hover checked; click not automated)
**Applies to:** any Omarchy machine

Omarchy's notifications can only be closed by right-clicking them. This adds a
macOS-style round "×" that appears on the notification's top-left corner, half
outside the card, while you hover over it. Right-click still works.

## Files

| File | What it does |
|---|---|
| `pavan.notifications/` | A clone of Omarchy's `omarchy.notifications` plugin with the button added |
| `omarchy-4.0.6.diff` | The change against Omarchy 4.0.6's original, for re-applying after updates |
| `../shell-plugin.sh` | Shared install / revert / status script |

The change, in two files:
- `components/NotificationCard.qml`: the button, which emits the card's existing
  `closeRequested()` (the same action as right-click), and `clip: false` so the
  button can stick out past the corner. The title and body already truncate
  themselves to a fixed number of lines.
- `Service.qml`: the popup layer only accepted clicks inside the card column. The
  input area is now 12px larger up and to the left, so the button's outer half takes clicks.

## Check
```
../shell-plugin.sh status pavan.notifications
```

## Install
```
cd customizations/notifications-close-button
../shell-plugin.sh install pavan.notifications
```
This copies the plugin to `~/.config/omarchy/plugins/pavan.notifications/`, enables
it (which disables `omarchy.notifications`), and restarts the shell.

## Verify
```
env -u LD_LIBRARY_PATH notify-send -t 30000 "Test" "Hover me"
```
Hover over the notification: a round "×" appears on its top-left corner. Clicking it
closes the notification. (`env -u LD_LIBRARY_PATH` is only needed when running from
an app that bundles its own libraries, like T3 Code.)

## Revert
```
../shell-plugin.sh revert pavan.notifications
```
The clone is backed up as a hidden folder in `~/.config/omarchy/plugins/` and the
original comes back.

## After an Omarchy update
The clone doesn't receive Omarchy's changes to the notifications plugin. If
notifications misbehave after an update, rebuild the clone from the new original:
```
../shell-plugin.sh revert pavan.notifications
omarchy plugin clone omarchy.notifications
cd ~/.config/omarchy/plugins/pavan.notifications
patch -p1 < /path/to/omarchy-vivobook-setup/customizations/notifications-close-button/omarchy-4.0.6.diff
```
If a hunk fails, re-apply it by hand. It's small: one `Rectangle` at the end of
`NotificationCard.qml`, `clip: false`, and the `mask: Region` in `Service.qml`. Then
copy the result back into this folder and regenerate the diff.

## Why a clone
Omarchy's shell plugins live in `/usr/share/omarchy/shell/plugins/` and get
overwritten on update. `omarchy plugin clone` is the supported way to change one.
