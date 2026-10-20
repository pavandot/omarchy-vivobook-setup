"""Golden Gate wallpaper: layered satin sheets in deep indigo with luminous edges.

Usage: python3 -I extras/make-wallpaper.py backgrounds/golden-gate-indigo.jpg
"""
import sys

import numpy as np
from PIL import Image

W, H = 3840, 2160
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = x / W, y / H
rng = np.random.default_rng(27)


def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255


def over(img, color, alpha):
    a = np.clip(alpha, 0, 1)[..., None]
    return img * (1 - a) + color * a


# Work in a frame rotated so the sheets sweep diagonally, bottom-left to top-right.
theta = np.deg2rad(-32)
cx, cy = (u - 0.5) * W / H, v - 0.5
s = cx * np.cos(theta) - cy * np.sin(theta)    # along the flow
t = cx * np.sin(theta) + cy * np.cos(theta)    # across the flow

# Night base: indigo-black, a touch lighter toward the upper left.
img = hexc('100f1a') + (hexc('1d1c2d') - hexc('100f1a')) * np.clip(1 - v * 0.9 - u * 0.4, 0, 1)[..., None]

# Sheets, back to front: (offset, amp, freq, phase, body colour, lip colour, rim colour)
sheets = [
    (-0.62, 0.20, 0.55, 0.4, '1a1928', '3a3854', '8f8fd6'),
    (-0.30, 0.17, 0.62, 1.9, '161624', '3d3c5c', '9a9be0'),
    (0.02, 0.15, 0.70, 3.0, '121322', '31354f', '8d97d4'),
    (0.34, 0.13, 0.80, 4.4, '0f1120', '2b3049', '9aa6d8'),
    (0.62, 0.11, 0.92, 5.6, '0d0f1c', '262b42', 'a4b0dc'),
]
for off, amp, freq, ph, body, lip, rim in sheets:
    edge = off + amp * np.sin(2 * np.pi * freq * s + ph) + amp * 0.3 * np.sin(2 * np.pi * freq * 1.9 * s + ph * 1.3)
    slope = 2 * np.pi * freq * amp * np.cos(2 * np.pi * freq * s + ph)
    d = (t - edge) / np.sqrt(1 + slope ** 2) * H   # signed distance in pixels, >0 on the sheet
    # Soft shadow the sheet casts onto whatever lies behind it.
    img = img * (1 - 0.55 * np.exp(np.clip(d, None, 0) / 140) * (d < 0))[..., None]
    # Sheet body: satin falloff from a lit lip into deep indigo.
    fall = np.exp(-np.clip(d, 0, None) / 520)[..., None]
    fill = hexc(body) + (hexc(lip) - hexc(body)) * fall
    img = over(img, fill, np.clip(d / 1.5 + 0.5, 0, 1))
    # Hairline luminous rim right on the edge, with a faint bloom.
    img = img + hexc(rim) * (np.exp(-(d / 2.2) ** 2) * 0.85 + np.exp(-(np.clip(d, 0, None) / 28)) * (d > 0) * 0.10)[..., None]

# Steel-blue light pooling on the right, a violet haze low left, and a vignette.
img = img + hexc('5f74a8') * (np.exp(-(((u - 1.02) / 0.22) ** 2 + ((v - 0.52) / 0.32) ** 2)) * 0.55)[..., None]
img = img + hexc('4a3f75') * (np.exp(-(((u - 0.12) / 0.25) ** 2 + ((v - 0.72) / 0.3) ** 2)) * 0.25)[..., None]
vig = 1 - 0.35 * (((u - 0.5) * 1.2) ** 2 + ((v - 0.5) * 1.3) ** 2)
img = img * np.clip(vig, 0.6, 1)[..., None]

img = img + (rng.random(img.shape, dtype=np.float32) - 0.5) / 255
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(sys.argv[1], quality=94, subsampling=0)
