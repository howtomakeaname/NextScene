#!/usr/bin/env python3
"""Export platform icon resources from the approved NextScene PNG master.

Requires Pillow; macOS exports also use rsvg-convert for the existing icon mask.
Run without arguments for all platforms, or pass --platform for a subset.
"""

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
MASTER = ROOT / "assets" / "nextscene_icon.png"
MASK_SVG = ROOT / "assets" / "apple_icon_mask.svg"
FLUTTER_APP = ROOT / "apps" / "flutter_app"
RESAMPLE = Image.Resampling.LANCZOS


def load_master():
    with Image.open(MASTER) as image:
        if image.width != image.height or image.width < 1024:
            raise ValueError("The icon master must be square and at least 1024px")
        if image.convert("RGBA").getchannel("A").getextrema() != (255, 255):
            raise ValueError("The approved square icon must be fully opaque")
        return image.convert("RGB")


def save_png(image, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), RESAMPLE).save(path, "PNG")


def catalog_sizes(path):
    """Use Xcode's existing catalog as the source of filenames and pixel sizes."""
    result = {}
    for entry in json.loads((path / "Contents.json").read_text())["images"]:
        name = entry.get("filename")
        if not name:
            continue
        width, height = map(float, entry["size"].split("x"))
        scale = float(entry["scale"].removesuffix("x"))
        if width != height:
            raise ValueError(f"Non-square app icon in {path}: {name}")
        size = round(width * scale)
        if name in result and result[name] != size:
            raise ValueError(f"Conflicting sizes for {name}")
        result[name] = size
    return result


def generate_shared(master):
    for name in ("app_icon.png", "app_icon_ohos.png"):
        save_png(master, FLUTTER_APP / "assets" / "branding" / name, 512)
    save_png(master, ROOT / "doc" / "store" / "app_icon_1024.png", 1024)


def generate_ohos(master):
    for path in (
        "AppScope/resources/base/media/app_icon.png",
        "entry/src/main/resources/base/media/icon.png",
        "entry/src/ohosTest/resources/base/media/icon.png",
    ):
        save_png(master, FLUTTER_APP / "ohos" / path, 1024)


def generate_android(master):
    res = FLUTTER_APP / "android" / "app" / "src" / "main" / "res"
    background = master.getpixel((0, 0))
    for density, legacy, adaptive in (
        ("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432),
    ):
        folder = res / f"mipmap-{density}"
        save_png(master, folder / "ic_launcher.png", legacy)
        # Keep the approved flattened artwork intact. The opaque foreground
        # extends beyond the launcher's viewport; its mark is inset to fit the
        # adaptive safe area. Both layers are unmasked 108dp bitmaps.
        foreground = Image.new("RGB", (adaptive, adaptive), background)
        inner = round(adaptive * 0.86)
        offset = (adaptive - inner) // 2
        foreground.paste(master.resize((inner, inner), RESAMPLE), (offset, offset))
        save_png(foreground, folder / "ic_launcher_foreground.png", adaptive)
        save_png(Image.new("RGB", (adaptive, adaptive), background),
                 folder / "ic_launcher_background.png", adaptive)
    colors = res / "values" / "ic_launcher_colors.xml"
    color = "#%02X%02X%02X" % background
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">{color}</color>\n'
        '</resources>\n'
    )


def generate_ios(master):
    folder = FLUTTER_APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in catalog_sizes(folder).items():
        # RGB, with no alpha or baked mask: iOS applies the icon shape.
        save_png(master, folder / name, size)


def generate_macos(master):
    folder = FLUTTER_APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    with tempfile.TemporaryDirectory(prefix="nextscene-icon-") as temp:
        mask_path = Path(temp) / "mask.png"
        subprocess.run([
            "rsvg-convert", "-w", "1024", "-h", "1024", str(MASK_SVG),
            "-o", str(mask_path),
        ], check=True)
        with Image.open(mask_path) as mask_image:
            mask = mask_image.convert("RGBA").getchannel("A")
        inner = 820
        tile = master.resize((inner, inner), RESAMPLE).convert("RGBA")
        tile.putalpha(mask.resize((inner, inner), RESAMPLE))
        canvas = Image.new("RGBA", (1024, 1024))
        canvas.alpha_composite(tile, ((1024 - inner) // 2,) * 2)
        for name, size in catalog_sizes(folder).items():
            save_png(canvas, folder / name, size)
        canvas.save(ROOT / "platforms/apple/macos/Icon.icns", "ICNS")


def generate_windows(master):
    path = FLUTTER_APP / "windows/runner/resources/app_icon.ico"
    path.parent.mkdir(parents=True, exist_ok=True)
    master.resize((256, 256), RESAMPLE).save(
        path, "ICO", sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)]
    )


def main():
    generators = {
        "shared": generate_shared, "ohos": generate_ohos,
        "android": generate_android, "ios": generate_ios,
        "macos": generate_macos, "windows": generate_windows,
    }
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", action="append", choices=generators,
                        help="Generate only these platform resources (repeatable)")
    args = parser.parse_args()
    master = load_master()
    for name in args.platform or generators:
        generators[name](master)
        print(f"Generated {name} icons from {MASTER.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
