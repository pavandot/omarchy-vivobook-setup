# Omarchy on ASUS VivoBook 14 X421IAY

> **Machine:** ASUS VivoBook 14 X421IAY / M413IA (AMD Ryzen 5 4500U)
> **OS:** Omarchy (Arch Linux + Hyprland). Last checked on Omarchy 4.0.4

Fixes for hardware and setup problems on this laptop, plus my desktop
customizations, so a clean reinstall is a checklist instead of a re-investigation.
Every fix and customization has its own folder with a guide (why it's needed, how to
apply it, how to check it, how to undo it) and any scripts it needs.

## On a fresh install

1. Install Omarchy and finish its first-boot setup.
2. `git clone https://github.com/pavandot/omarchy-vivobook-setup.git`
3. Work through the fixes in the table below, in order. Each guide starts with how to
   check whether the fix is still needed: Omarchy or upstream may have fixed it since.
4. Apply the customizations. Do the fingerprint fix first: the password prompt
   redesign shows the fingerprint view only once fingerprint is set up in PAM.

The guides are written so an AI agent can follow them too: point it at a fix's
`README.md`, and confirm before it changes PAM, boot or disk settings.

## Fixes

| # | Fix | Problem | Status |
|---|-----|---------|--------|
| 1 | [ELAN 0903 fingerprint](fixes/elan-0903-fingerprint/) | Fingerprint reader detected but enrollment always fails | ✅ Working (2026-10-17) |

## Customizations

Changes to how Omarchy looks and behaves. They work on any Omarchy machine; the scale presets suit any 1080p laptop.

| Customization | What it does | Install | Status |
|---|---|---|---|
| [Display scale presets](customizations/display-scale-presets/) | Adds 1.33× and 1.5× to the Display dropdown's scale buttons, for the 14″ 1080p screen (moved here from `fixes/`) | `../shell-plugin.sh install pavan.monitor`, then `omarchy hyprland monitor scaling 1.5` | ✅ Working (2026-10-20) |
| [Golden Gate theme](customizations/golden-gate-theme/) | macOS 27 "Golden Gate" dark mode: palette, transparent bar, frosted glass, window corners and gaps, T3 Code and browser colours | `./install.sh install --apple-wallpapers` | ✅ Working (2026-10-20) |
| [Notification close button](customizations/notifications-close-button/) | macOS-style "×" on a notification's corner while hovered | `../shell-plugin.sh install pavan.notifications` | ✅ Working (2026-10-20) |
| [Touch ID-style password prompt](customizations/polkit-touch-id-prompt/) | Redesigns the polkit prompt as a macOS Touch ID sheet, with fingerprint and password views | `../shell-plugin.sh install pavan.polkit` | ✅ Working (2026-10-20) |

The three plugin customizations are clones of Omarchy's own shell plugins, made with
`omarchy plugin clone`. Each folder has a diff against Omarchy 4.0.6's original,
for re-applying the change after an Omarchy update changes the plugin.

## Adding a fix

Create `fixes/<short-name>/README.md` (or `customizations/<short-name>/README.md`)
with these sections, then add a row above:

- **Status / Applies to:** date verified, Omarchy version, hardware it applies to
- **Check:** a command that shows whether the fix is still needed
- **Install:** numbered steps, with what to expect after each one
- **Verify:** how to prove it works
- **Revert:** how to undo it completely
- **Why:** the root cause, and any upstream issues or MRs to watch

Keep scripts next to the guide. Back up any system file before changing it, and make
every change revertible.
