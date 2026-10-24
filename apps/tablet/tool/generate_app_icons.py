#!/usr/bin/env python3
"""Regenerate tablet icons on macOS using sips; leave the phone app untouched."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile


APP = Path(__file__).resolve().parents[1]
SOURCE = APP / "assets/AppIconSource.png"
CATALOG = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"


def outputs():
    result = {}
    for image in json.loads((CATALOG / "Contents.json").read_text())["images"]:
        width, height = map(float, image["size"].split("x"))
        scale = float(image["scale"].removesuffix("x"))
        assert width == height and (width * scale).is_integer()
        result[CATALOG / image["filename"]] = int(width * scale)
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                          "xxhdpi": 144, "xxxhdpi": 192}.items():
        result[APP / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"] = size
    for name, size in {"Icon-192": 192, "Icon-512": 512,
                       "Icon-maskable-192": 192, "Icon-maskable-512": 512}.items():
        result[APP / f"web/icons/{name}.png"] = size
    result[APP / "web/favicon.png"] = 32
    return result


def properties(path):
    output = subprocess.check_output(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
        text=True,
    )
    return dict(line.strip().split(": ", 1) for line in output.splitlines()[1:])


def validate(expected):
    source = properties(SOURCE)
    assert int(source["pixelWidth"]) == int(source["pixelHeight"]) >= 1024
    for path, size in expected.items():
        actual = properties(path)
        assert int(actual["pixelWidth"]) == int(actual["pixelHeight"]) == size, path
        assert actual["hasAlpha"] == "no", path
    manifest = json.loads((APP / "web/manifest.json").read_text())
    for icon in manifest["icons"]:
        size = expected[APP / "web" / icon["src"]]
        assert icon["sizes"] == f"{size}x{size}"
    print(f"Validated {len(expected)} opaque PNG icons, iOS catalog and web manifest.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate without regenerating")
    args = parser.parse_args()
    expected = outputs()
    if not args.check:
        with tempfile.TemporaryDirectory(prefix="tripling-table-icons-") as temporary:
            temporary = Path(temporary)
            opaque = temporary / "opaque.png"
            # ImageIO writes RGB PNG losslessly; sips retains alpha on PNG input.
            # All platform resizing is performed by sips from this full-size image.
            subprocess.run([
                "swift", "-module-cache-path", str(temporary / "swift-cache"),
                str(APP / "tool/opaque_app_icon.swift"), str(SOURCE), str(opaque),
            ], check=True)
            for path, size in expected.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run([
                    "sips", "-z", str(size), str(size), str(opaque), "--out", str(path),
                ], check=True, stdout=subprocess.DEVNULL)
    validate(expected)


if __name__ == "__main__":
    main()
