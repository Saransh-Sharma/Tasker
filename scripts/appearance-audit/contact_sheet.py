#!/usr/bin/env python3
"""Tile audit captures side by side.

    contact_sheet.py <out.png> <scale> <png> [<png> ...]

Images are laid out left to right in argument order at 1/scale size, with the
file stem printed above each so a reviewer can name the cell a finding is in.
"""
import os
import sys

from PIL import Image, ImageDraw


def main():
    out, scale, paths = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    images = [Image.open(p).convert("RGB") for p in paths]
    w = max(i.width for i in images) // scale
    h = max(i.height for i in images) // scale
    label = 28
    sheet = Image.new("RGB", (w * len(images) + 8 * (len(images) - 1), h + label), (128, 128, 128))
    draw = ImageDraw.Draw(sheet)
    for index, (path, image) in enumerate(zip(paths, images)):
        x = index * (w + 8)
        sheet.paste(image.resize((w, h)), (x, label))
        stem = os.path.basename(path).replace(".png", "").replace("--", " ")
        draw.text((x + 4, 6), stem, fill=(255, 255, 255))
    sheet.save(out)


if __name__ == "__main__":
    main()
