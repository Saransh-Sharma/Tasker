#!/usr/bin/env python3
"""Measure WCAG contrast of text inside a region of a screenshot.

    measure_contrast.py <png> x0,y0,x1,y1 [x0,y0,x1,y1 ...]

Coordinates are in the PNG's own pixels. For each region the pixels are split
into two clusters by luminance (a 2-means on relative luminance); the larger
cluster is the background, the smaller the ink. The ink colour is taken from
the cluster's most extreme decile rather than its mean, so antialiased glyph
edges do not drag the ratio toward the background. Reports both colours and
the ratio, flagged against 4.5 (text) and 3.0 (large text / icons).
"""
import sys

import numpy as np
from PIL import Image


def srgb_to_linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    lin = srgb_to_linear(np.asarray(rgb, dtype=float))
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def ratio(l1, l2):
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def measure(img, box):
    region = np.asarray(img.crop(box).convert("RGB"), dtype=float).reshape(-1, 3)
    lum = luminance(region)
    lo, hi = np.percentile(lum, 5), np.percentile(lum, 95)
    centers = np.array([lo, hi])
    for _ in range(20):
        labels = np.abs(lum[:, None] - centers[None, :]).argmin(axis=1)
        for k in range(2):
            if (labels == k).any():
                centers[k] = lum[labels == k].mean()
    counts = np.bincount(labels, minlength=2)
    bg_k = int(counts.argmax())
    ink_k = 1 - bg_k
    bg_px = region[labels == bg_k]
    ink_px = region[labels == ink_k]
    if len(ink_px) == 0:
        return None
    bg_lum = np.median(lum[labels == bg_k])
    ink_lums = lum[labels == ink_k]
    # Most extreme decile of the ink cluster = glyph cores.
    if centers[ink_k] < centers[bg_k]:
        core = ink_lums <= np.percentile(ink_lums, 10)
    else:
        core = ink_lums >= np.percentile(ink_lums, 90)
    ink_lum = ink_lums[core].mean()
    ink_rgb = ink_px[core].mean(axis=0)
    bg_rgb = np.median(bg_px, axis=0)
    return ratio(ink_lum, bg_lum), ink_rgb, bg_rgb, counts[ink_k] / counts.sum()


def hexof(rgb):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in rgb)


def main():
    img = Image.open(sys.argv[1])
    for spec in sys.argv[2:]:
        box = tuple(int(v) for v in spec.split(","))
        result = measure(img, box)
        if result is None:
            print(f"{spec}: uniform region")
            continue
        r, ink, bg, share = result
        flag = "FAIL<3" if r < 3 else ("FAIL<4.5" if r < 4.5 else "ok")
        print(f"{spec}: {r:5.2f}:1  ink {hexof(ink)} on {hexof(bg)}  ink {share:.0%}  {flag}")


if __name__ == "__main__":
    main()
