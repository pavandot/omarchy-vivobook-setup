# Touch ID-style password prompt

**Status:** ✅ working, verified 2026-10-20 on Omarchy 4.0.6
**Applies to:** any Omarchy machine. Fingerprint needs [fix 1](../../fixes/elan-0903-fingerprint/) on this laptop

Omarchy's polkit prompt (the dialog for `pkexec` and other admin actions) is a small
square with a fingerprint icon, plus a separate monospace label above it. This
redesigns it as a macOS Touch ID sheet, in one frosted panel:

1. A padlock tile at the top
2. A bold title naming the action, e.g. "Authorize running '/usr/bin/true'"
3. One line of instructions: "Touch the fingerprint sensor to allow this." or "Enter
   your password to allow this.". It changes to "Checking…" while checking and to
   "Try again." in red after a failure (the panel still shakes)
4. **Fingerprint view:** a large pink-red fingerprint with a soft halo, and **Cancel**
5. **Password view:** a rounded field with a blue focus ring, **Cancel** and **OK**

Text uses Adwaita Sans, the closest installed font to Apple's SF Pro. The
authentication logic is unchanged: only the part of `PolkitAgent.qml` that draws the
dialog was rewritten. Enter submits and Escape cancels, as before.

## Files

| File | What it does |
|---|---|
| `pavan.polkit/` | A clone of Omarchy's `omarchy.polkit` plugin with the new layout |
| `omarchy-4.0.6.diff` | The change against Omarchy 4.0.6's original |
| `../shell-plugin.sh` | Shared install / revert / status script |

## Check
```
../shell-plugin.sh status pavan.polkit
```

## Install
```
cd customizations/polkit-touch-id-prompt
../shell-plugin.sh install pavan.polkit
```
This copies the plugin to `~/.config/omarchy/plugins/pavan.polkit/`, enables it
(disabling `omarchy.polkit`), and restarts the shell. Check that the agent registered:
`journalctl --user -t omarchy-shell -n 50 | grep "polkit agent registered"`.

## Verify
```
pkexec /usr/bin/true
```
- With fingerprint set up: the sheet shows the pink fingerprint. Touch the sensor; the
  sheet closes and `pkexec` exits without an error.
- Run it again without touching the sensor: after 20 seconds (`timeout=20` in
  `/etc/pam.d/polkit-1`) it switches to the password view.
- Escape cancels: `pkexec` prints "Request dismissed".

## Revert
```
../shell-plugin.sh revert pavan.polkit
```

## Notes
- **No "Use Password…" button.** While `pam_fprintd` is waiting, a polkit agent
  can't skip ahead to the password step. The password view appears after the
  fingerprint timeout or 3 failed fingerprints.
- **The pink colour is fixed** (`#ff375f`, Touch ID's colour) and doesn't follow the
  theme accent. Everything else uses the theme's `[polkit]` colours.
- **After an Omarchy update:** rebuild the clone and apply `omarchy-4.0.6.diff`, as
  described in [the notifications guide](../notifications-close-button/#after-an-omarchy-update).
