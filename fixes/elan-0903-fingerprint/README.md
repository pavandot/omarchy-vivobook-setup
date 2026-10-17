# ELAN 04f3:0903 fingerprint reader

**Status:** ✅ working, verified 2026-10-17 on Omarchy 4.0.4 (fprintd 1.94.5, OpenCV 5.0)
**Applies to:** ASUS VivoBook 14 X421IAY / M413IA, or any machine where
`lsusb` shows `04f3:0903`

Stock libfprint detects this reader, but enrollment fails with
`enroll-retry-scan` → `enroll-unknown-error` / "Calibration failed". This fix
installs a patched libfprint and enables fingerprint for sudo, polkit, TTY login
and the lock screen. The password always keeps working as a fallback.

## Files

| File | What it does |
|---|---|
| `PKGBUILD` | Builds `libfprint-elan0903` from [pavandot/libfprint-elan0903](https://github.com/pavandot/libfprint-elan0903) (branch `elan-0903`) |
| `fingerprint-pam.sh` | `install` / `revert` / `status` / `test-fallback` for the PAM changes. Backs up every file it touches |
| `pamtest.c` | Small PAM client used by `test-fallback` |

## Rules

- **Never run Omarchy's Setup → Security → Fingerprint** (`omarchy-setup-security-fingerprint`).
  It installs `libfprint-git` over this package and brings back the broken driver
  (Omarchy issue [#11899](https://github.com/omacom/omarchy/issues/11899)).
  `fingerprint-pam.sh install` sets up the same PAM stacks Omarchy would, including
  its lid-closed gate.
- Keep password login working at every step. `pam_fprintd` is only ever added as
  `sufficient` before the normal password stack.
- Prints live in `/var/lib/fprint`. Nothing is written to the sensor and no firmware
  is flashed.

## Install

### 1. Check the hardware
```
lsusb | grep -i 04f3:0903
```
If nothing is printed, stop. This fix only changes behaviour for 04f3:0903.

### 2. Build and install the driver
```
sudo pacman -S --needed base-devel git fprintd
cd fixes/elan-0903-fingerprint
makepkg -si          # replaces stock libfprint / libfprint-git: answer "y"
```
Check: `fprintd-list "$USER"` shows `ElanTech Fingerprint Sensor (press)`. If it
says `(swipe)`, the stock library is still loaded: run `sudo systemctl restart fprintd`.

### 3. Enroll
Tap the finger about 15 times. Lift it fully each time and shift it slightly
(centre, edges, tip). No swiping.
```
fprintd-enroll -f right-index-finger "$USER"
```
Expect 15 × `enroll-stage-passed`, then `enroll-completed`.

### 4. Verify
Touch, then lift. Repeat about 10 times, then try a few other fingers:
```
fprintd-verify -f right-index-finger "$USER"
```
Expect `verify-match` at least 9 times out of 10, and `verify-no-match` for every
other finger.

### 5. Enable fingerprint in PAM
Only after step 4 passes:
```
./fingerprint-pam.sh install         # sudo, polkit, TTY login, Omarchy lock screen
./fingerprint-pam.sh test-fallback   # proves the password still works in each stack
./fingerprint-pam.sh status
```
`test-fallback` creates a temporary user with a random password, checks that the
right password is accepted and a wrong one rejected in every stack, then deletes the
user. If any stack prints `PASSWORD FALLBACK BROKEN`, run `./fingerprint-pam.sh revert`
right away.

Then test it live:
- **sudo:** `sudo -k; sudo true`, then touch the sensor. A `NOPASSWD` rule in
  `/etc/sudoers.d/` skips authentication completely, so remove any such rule first.
- **Wrong finger 3 times:** a password prompt must appear.
- **Lock screen:** lock with Super+Ctrl+L, then touch the sensor to unlock. The
  password also works.

## Revert
```
./fingerprint-pam.sh revert   # restore PAM from the backup
sudo pacman -S libfprint      # stock driver back (accept replacing libfprint-elan0903)
```

## Troubleshooting
- **Fingerprint stops working after a system update** (password still works).
  Usually an OpenCV or glib soname bump. Check
  `ldd /usr/lib/libfprint-2.so.2 | grep "not found"`, then rebuild with
  `makepkg -sif` in this folder.
- **`(swipe)` in `fprintd-list`, or swipe prompts:** stock libfprint or
  `libfprint-git` got reinstalled. Repeat step 2.
- **Prints enrolled with another libfprint build don't match:** delete them with
  `fprintd-delete "$USER"` and enroll again.
- **Debug log:** `sudo systemctl stop fprintd; sudo G_MESSAGES_DEBUG=all /usr/lib/fprintd -t`.
  Look for `sensor dimensions, WxH: 80x80`, `press image from frame`,
  `sigfm score N/24`, `calibration failed`.
- A harmless "Deactivating image device while it is not idle" warning appears at the
  end of enrollment, because the driver waits for the finger to be really lifted.

## Why stock libfprint fails

- The 0903 is an **80×80 px (~500 dpi, ~4×4 mm) press sensor**, and matching
  happens on the host. Windows uses it as a tap sensor with 15–17 enroll touches.
- libfprint's `elan` driver treats every ELAN reader as a **swipe** sensor. It crops
  frames to 50 rows and stitches about 30 of them, so a tap gives a garbage image.
- It reports the finger as lifted right after a scan and recalibrates while the finger
  is still on the sensor, which causes `Calibration failed`.
- Even with correct images, NBIS (libfprint's default matcher) finds a median of
  **2 minutiae** on 80×80 and needs about 10, so it can never match.

The patched library uses the SIGFM matcher from upstream
[MR !530](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/530),
which is built for small sensors, plus 4 patches:
1. `elan: treat 04f3:0903 as a press sensor`: one settled full frame per touch, no
   stitching, waits for the finger to be lifted, 15 enroll stages.
2. `elan: 0903: make calibration and capture robust`: 50 calibration polls, waits if
   a finger rests on the sensor during calibration, retries "not ready" and faint images.
3. `print: support sigfm prints in fp_print_equal()`
4. `device: skip gallery equality check for sigfm prints` (3 and 4 fix bugs in !530)

## Results (2026-10-17)
- Enroll: 15 taps, no rejections.
- Verify: 25/25 matches with the enrolled finger, 13/13 attempts with other fingers
  rejected.
- Offline, 61 recorded taps: 0 false matches in 2,320 cross-finger pairs.
- PAM: sudo, polkit and TTY login matched by fingerprint, wrong finger ×3 fell back to
  the password, the lock screen unlocked by fingerprint.

These scores were measured before the fix for a known SIGFM matcher bug
(`match::operator<` in `sigfm.cpp`). Re-test if that fix is added to the fork.

## Upstream status
- Patches posted on [!530](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/530#note_3718822)
  (2026-10-17). Related issues: #556, #749, #817, #445.
- !530 has been open since 2025 without maintainer review (false-accept benchmarks,
  red CI, migration of existing prints).
- When a stock libfprint release supports the 0903 as a press sensor with SIGFM,
  revert to it.
