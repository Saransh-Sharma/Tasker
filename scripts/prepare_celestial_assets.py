#!/usr/bin/env python3
"""Prepare LifeBoard's supplied celestial artwork for the asset catalog.

The source files remain untouched. Celestial images are cleaned by retaining
only pixels within four pixels of the primary, mostly-opaque body. Backgrounds
are made explicitly opaque. Every output is tagged sRGB and emitted with the
catalog metadata expected by Xcode.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageCms, ImageFilter


PHASES = (
    ("Dawn", "DAWN_BG.png", "CelestialDawnSun.png"),
    ("Morning", "MORNING_BG.png", "CelestialMorningSun.png"),
    ("Midday", "MIDDAY_BG.png", "CelestialMiddaySun.png"),
    ("GoldenHour", "GOLDENHOUR_BG.png", "CelestialGoldenHourSun.png"),
    ("Twilight", "TWILIGHT_BG.png", "CelestialTwilightMoon.png"),
    ("Night", "NIGHT_BG.png", "CelestialNightMoon.png"),
)


def catalog_json(images: list[dict[str, str]]) -> dict[str, object]:
    return {
        "images": images,
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }


def srgb_bytes() -> bytes:
    profile = ImageCms.createProfile("sRGB")
    return ImageCms.ImageCmsProfile(profile).tobytes()


def cleaned_celestial(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    # The body is consistently opaque while the unwanted square-canvas haze
    # is below this threshold. Dilating the body by 4 px retains the soft edge.
    body = alpha.point(lambda value: 255 if value >= 128 else 0)
    retained_region = body.filter(ImageFilter.MaxFilter(9))
    clean_alpha = Image.new("L", alpha.size, 0)
    clean_alpha.paste(alpha, mask=retained_region)
    image.putalpha(clean_alpha)
    return image


def save_catalog_image(image: Image.Image, destination: Path, *, profile: bytes) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, format="PNG", optimize=True, icc_profile=profile)


def write_contents(path: Path, contents: dict[str, object]) -> None:
    path.write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def prepare(source_dir: Path, catalog: Path) -> None:
    profile = srgb_bytes()
    group = catalog / "CelestialAtmospheres"
    group.mkdir(parents=True, exist_ok=True)
    write_contents(group / "Contents.json", {"info": {"author": "xcode", "version": 1}})

    for phase, background_name, celestial_name in PHASES:
        background_source = source_dir / background_name
        celestial_source = source_dir / celestial_name
        if not background_source.is_file() or not celestial_source.is_file():
            raise FileNotFoundError(f"Missing source pair for {phase}")

        background_set = group / f"Celestial{phase}Background.imageset"
        background = Image.open(background_source).convert("RGB")
        background_output = f"Celestial{phase}Background.png"
        save_catalog_image(background, background_set / background_output, profile=profile)
        write_contents(
            background_set / "Contents.json",
            catalog_json([
                {
                    "filename": background_output,
                    "idiom": "universal",
                    "scale": "1x",
                }
            ]),
        )

        celestial_set = group / f"Celestial{phase}.imageset"
        celestial = cleaned_celestial(celestial_source)
        celestial_entries: list[dict[str, str]] = []
        resampling = Image.Resampling.LANCZOS
        for size, scale in ((418, "1x"), (836, "2x"), (1254, "3x")):
            output_name = f"Celestial{phase}@{scale}.png"
            resized = celestial if celestial.width == size else celestial.resize((size, size), resampling)
            save_catalog_image(resized, celestial_set / output_name, profile=profile)
            celestial_entries.append(
                {"filename": output_name, "idiom": "universal", "scale": scale}
            )
        write_contents(celestial_set / "Contents.json", catalog_json(celestial_entries))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("LifeBoard/Assets.xcassets"),
    )
    args = parser.parse_args()
    prepare(args.source_dir.resolve(), args.catalog.resolve())


if __name__ == "__main__":
    main()
