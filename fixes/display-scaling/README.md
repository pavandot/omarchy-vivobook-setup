# Display scaling (1.33×) and Display panel presets

**Status:** ✅ working, verified 2026-10-17 on Omarchy 4.0.4
**Applies to:** ASUS VivoBook 14 X421IAY / M413IA (14″ 1920×1080 BOE panel, about
31×17 cm, ~157 dpi), or any 1080p laptop panel

Sets the panel to **1.33×** (a 1440×810 workspace, between Windows' 125% and 150%)
and replaces the Display panel's scale buttons with ones that suit a 1080p screen:

| | Scale buttons |
|---|---|
| Stock Omarchy | `1x · 1.25x · 1.6x · 2x · 3x · 4x` |
| After this fix | `1x · 1.25x · 1.33x · 1.5x · 1.6x · 2x` |

Text size is left at Omarchy's default: 12px in the shell, GTK factor 1.0, **9pt** in
the terminals.

## Files

| File | What it does |
|---|---|
| `display-scaling.sh` | `install [SCALE]` / `revert` / `status`. Backs up `monitors.lua` and `shell.json` before changing them |

## Check
```
./display-scaling.sh status
```
Not needed if `Panel:` already lists 1.33 and 1.5, for example because Omarchy
shipped dynamic presets (see [Why](#why)).

## Install
Run inside the Hyprland session (not over SSH or from a TTY):
```
cd fixes/display-scaling
./display-scaling.sh install          # or: install 1.5 / install 1.25
```
What it does:
1. Backs up `~/.config/hypr/monitors.lua`, then runs
   `omarchy hyprland monitor scaling 1.33`. Hyprland rounds this to exactly 4/3,
   `hyprctl monitors` shows `scale: 1.3333334`, and the scale is saved in
   `monitors.lua` so it lasts after a reboot.
2. Copies the stock Display panel with `omarchy plugin clone omarchy.monitor` to
   `~/.config/omarchy/plugins/$USER.monitor/` and switches the bar to the copy.
   `omarchy update` doesn't overwrite it. If the copy already exists, it is reused.
3. Replaces the `scalePresets` line in the copy's `Panel.qml`.
4. Restarts the shell. The shell's hot reload doesn't always load a freshly cloned
   panel, so without the restart the stock buttons can stay on screen.

Backups go to `~/.local/state/omarchy-vivobook-setup/display-scaling/`.

## Verify
- `./display-scaling.sh status` shows `scale 1.3333334`, `Bar widget: <user>.monitor`
  and the six buttons.
- Click the display icon in the bar: the **SCALE** row shows
  `1x 1.25x 1.33x 1.5x 1.6x 2x` with **1.33x** highlighted.

## Revert
```
./display-scaling.sh revert
```
This restores `monitors.lua` from the first backup (the state before the first
install) and runs `omarchy plugin remove <user>.monitor --yes`, which moves the copy
to `~/.config/omarchy/plugins/.<user>.monitor.bak.*` and puts the stock
`omarchy.monitor` back in the bar.

## Notes
- **Scale shortcuts:** the keyboard scale up/down uses `omarchy-hyprland-monitor-scaling`,
  which has its own fixed list (1, 1.25, 1.6, 2, 3, 4) in `/usr/share/omarchy`. It
  skips 1.33 and 1.5, and that file isn't changed here.
- **Clicking a button** in the panel replaces the scale, and the choice is saved.
  `omarchy-hyprland-monitor-scaling` logs who changed the scale and when in
  `~/.local/state/omarchy/monitor-scaling.log`.
- **Changing text size:** use the panel's TEXT SIZE slider or
  `omarchy display text size <9-20>`, which sets the shell, GTK and terminal sizes
  together (terminal pt = px × 9/12). `omarchy display text size reset` goes back to
  the defaults.
- The copy of the panel doesn't get Omarchy's later fixes to the Display panel. Run
  `revert` and then `install` again after a big Omarchy update to pick them up.

## Why
- Hyprland only accepts scales where the resolution divides into whole logical pixels,
  in 1/120 steps. On 1920×1080 the usable scales between 1 and 2 are
  1, 1.2, 1.25, 1.33, 1.5, 1.6, 1.67, 1.875 and 2.
- The Display panel has the fixed list `["1", "1.25", "1.6", "2", "3", "4"]`
  (`shell/plugins/panels/monitor/Panel.qml`). 1.33 and 1.5 are missing, and on 1080p
  3× and 4× leave a 640×360 or 480×270 workspace.
- On this 14″ panel, 1× is too small to read comfortably and 1.5× (Windows' default
  of 150%) makes everything large. 1.33× sits in between.

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
  1.5. This fix keeps both available.
- When a release with that change is out, run `revert` and set the scale from the
  stock panel.
