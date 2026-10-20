# Display scale presets (1.33× and 1.5×)

**Status:** ✅ working, verified 2026-10-20 on Omarchy 4.0.6 (first set up 2026-10-17 on 4.0.4)
**Applies to:** ASUS VivoBook 14 X421IAY / M413IA (14″ 1920×1080 BOE panel, about
31×17 cm, ~157 dpi), or any 1080p laptop panel

Replaces the Display dropdown's scale buttons with ones that suit a 1080p screen, and
sets the panel's scale:

| | Scale buttons |
|---|---|
| Stock Omarchy | `1x · 1.25x · 1.6x · 2x · 3x · 4x` |
| With this change | `1x · 1.25x · 1.33x · 1.5x · 1.6x · 2x` |

1.33× gives a 1440×810 workspace, between Windows' 125% and 150%. 1.5× (Windows'
default of 150%) gives 1280×720. This laptop currently runs at 1.5×.

## Files

| File | What it does |
|---|---|
| `pavan.monitor/` | A clone of Omarchy 4.0.6's `omarchy.monitor` Display panel. The only change is the `scalePresets` line in `Panel.qml` |
| `omarchy-4.0.6.diff` | That change against Omarchy 4.0.6's original |
| `../shell-plugin.sh` | Shared install / revert / status script |

## Check
```
../shell-plugin.sh status pavan.monitor
hyprctl monitors -j | jq '.[] | {name, scale}'
```
Not needed if the stock Display dropdown already lists 1.33 and 1.5, for example
because Omarchy shipped dynamic presets (see [Upstream status](#upstream-status)).

## Install
Run inside the Hyprland session (not over SSH or from a TTY):
```
cd customizations/display-scale-presets
../shell-plugin.sh install pavan.monitor
omarchy hyprland monitor scaling 1.5     # or 1.33
```
1. `shell-plugin.sh install` copies the panel to `~/.config/omarchy/plugins/pavan.monitor/`,
   enables it in the bar in place of `omarchy.monitor`, and restarts the shell. The
   restart matters: hot reload doesn't always swap in a freshly installed panel.
2. `omarchy hyprland monitor scaling` sets the scale and saves it in
   `~/.config/hypr/monitors.lua`, so it lasts after a reboot. Hyprland rounds 1.33 to
   exactly 4/3 (`hyprctl monitors` shows `1.3333334`). Clicking a button in the
   dropdown does the same thing.

## Verify
- `../shell-plugin.sh status pavan.monitor` shows `pavan.monitor: enabled` and
  `Installed copy matches this repo.`
- Click the display icon in the bar: the **SCALE** row shows
  `1x 1.25x 1.33x 1.5x 1.6x 2x`, with the current scale highlighted.

## Revert
```
../shell-plugin.sh revert pavan.monitor
omarchy hyprland monitor scaling 1.25    # or whichever stock scale you want
```
The clone is backed up as a hidden folder in `~/.config/omarchy/plugins/` and the
stock `omarchy.monitor` comes back in the bar.

## After an Omarchy update
The clone doesn't get Omarchy's later fixes to the Display panel. The first version
of this change (2026-10-17, Omarchy 4.0.4) missed one: in 4.0.6 Omarchy switched the
display on/off toggle from `hyprctl keyword monitor` to `hyprctl eval`, because
`keyword` is rejected under the Lua config. The old clone kept the broken command.

So after an Omarchy update that touches `shell/plugins/panels/monitor/`, rebuild the
clone from the new original:
```
../shell-plugin.sh revert pavan.monitor
omarchy plugin clone omarchy.monitor
sed -i -E 's/^([[:space:]]*readonly property var scalePresets: )\[.*\]/\1["1", "1.25", "1.33", "1.5", "1.6", "2"]/' \
  ~/.config/omarchy/plugins/pavan.monitor/Panel.qml
omarchy restart shell
```
Then copy `~/.config/omarchy/plugins/pavan.monitor/` back into this folder and
regenerate the diff. If the `sed` changes nothing, the `scalePresets` line changed
upstream: check whether the stock panel now covers 1.33 and 1.5 before editing it by hand.

## Notes
- **Scale shortcuts:** the keyboard scale up/down uses `omarchy-hyprland-monitor-scaling`,
  which has its own fixed list (1, 1.25, 1.6, 2, 3, 4) in `/usr/share/omarchy`. It
  skips 1.33 and 1.5, and that file isn't changed here.
- **Scale changes are logged** by `omarchy-hyprland-monitor-scaling` in
  `~/.local/state/omarchy/monitor-scaling.log` (who changed it, and when).
- **Changing text size:** use the dropdown's TEXT SIZE slider or
  `omarchy display text size <9-20>`, which sets the shell, GTK and terminal sizes
  together (terminal pt = px × 9/12). `omarchy display text size reset` goes back to
  the defaults.
- **Moved from `fixes/display-scaling/`** (2026-10-20). Its `display-scaling.sh`
  reused an existing clone instead of re-cloning, which is how the clone went stale.
  The shared `shell-plugin.sh` always installs the copy in this folder.

## Why
- Hyprland only accepts scales where the resolution divides into whole logical pixels,
  in 1/120 steps. On 1920×1080 the usable scales between 1 and 2 are
  1, 1.2, 1.25, 1.33, 1.5, 1.6, 1.67, 1.875 and 2.
- The Display panel has the fixed list `["1", "1.25", "1.6", "2", "3", "4"]`
  (`shell/plugins/panels/monitor/Panel.qml`). 1.33 and 1.5 are missing, and on 1080p
  3× and 4× leave a 640×360 or 480×270 workspace.
- On this 14″ panel, 1× is too small to read comfortably. 1.33× and 1.5× are the two
  comfortable sizes.

## Upstream status
- Issue [#14983](https://github.com/omacom/omarchy/issues/14983) and PR
  [#14986](https://github.com/omacom/omarchy/pull/14986) (open as of 2026-10-17)
  generate the buttons from the resolution. Tested on 1920×1080, the buttons depend on
  the active scale:

  | Active scale | PR #14986 buttons |
  |---|---|
  | 1, 1.2, 1.25, 1.5, 1.67, 1.875, 2 | `1, 1.25, 1.5, 1.67, 1.875, 2` (1.2 swaps in for 1.25 when 1.2 is active) |
  | 1.33 or 1.6 | `1, 1.2, 1.33, 1.6, 1.875, 2` (no 1.5) |

  So with the PR you can't pick 1.33 from the default row, and at 1.33 you can't pick
  1.5. This change keeps both available.
- When a release with that change is out, run `revert` and set the scale from the
  stock panel.
