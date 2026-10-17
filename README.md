# Omarchy on ASUS VivoBook 14 X421IAY

> **Machine:** ASUS VivoBook 14 X421IAY / M413IA (AMD Ryzen 5 4500U)
> **OS:** Omarchy (Arch Linux + Hyprland). Last checked on Omarchy 4.0.4

Fixes for hardware and setup problems on this laptop, so a clean reinstall is a
checklist instead of a re-investigation. Every fix has its own folder with a guide
(why it's needed, how to apply it, how to check it, how to undo it) and any scripts
it needs.

## On a fresh install

1. Install Omarchy and finish its first-boot setup.
2. `git clone https://github.com/pavandot/omarchy-vivobook-setup.git`
3. Work through the fixes in the table below, in order. Each guide starts with how to
   check whether the fix is still needed: Omarchy or upstream may have fixed it since.

The guides are written so an AI agent can follow them too: point it at a fix's
`README.md`, and confirm before it changes PAM, boot or disk settings.

## Fixes

| # | Fix | Problem | Status |
|---|-----|---------|--------|
| 1 | [ELAN 0903 fingerprint](fixes/elan-0903-fingerprint/) | Fingerprint reader detected but enrollment always fails | ✅ Working (2026-10-17) |
| 2 | [Display scaling](fixes/display-scaling/) | Display panel has no 1.33× or 1.5× for the 14″ 1080p screen. Sets 1.33× | ✅ Working (2026-10-17) |

## Adding a fix

Create `fixes/<short-name>/README.md` with these sections, then add a row above:

- **Status / Applies to:** date verified, Omarchy version, hardware it applies to
- **Check:** a command that shows whether the fix is still needed
- **Install:** numbered steps, with what to expect after each one
- **Verify:** how to prove it works
- **Revert:** how to undo it completely
- **Why:** the root cause, and any upstream issues or MRs to watch

Keep scripts next to the guide. Back up any system file before changing it, and make
every change revertible.
