#!/usr/bin/env python3
"""Generate AppIcon.icns from existing PNG icons using macOS iconutil."""

import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_SRC = os.path.join(
    ROOT, "frontend_flutter", "macos", "Runner",
    "Assets.xcassets", "AppIcon.appiconset",
)
OUTPUT_ICNS = os.path.join(ROOT, "packaging", "AppIcon.icns")


# iconutil expects an .iconset directory with specific filenames:
#   icon_16x16.png, icon_16x16@2x.png, icon_32x32.png, ...
SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

# Map from our PNG sizes to source filenames
SIZE_TO_SRC = {
    16: "app_icon_16.png",
    32: "app_icon_32.png",
    64: "app_icon_64.png",
    128: "app_icon_128.png",
    256: "app_icon_256.png",
    512: "app_icon_512.png",
    1024: "app_icon_1024.png",
}


def main():
    if sys.platform != "darwin":
        print("iconutil is macOS-only; skipping .icns generation")
        return

    if not os.path.isdir(ICON_SRC):
        print(f"Icon source not found: {ICON_SRC}")
        sys.exit(1)

    iconset_dir = os.path.join(ROOT, "packaging", "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    for size_px, target_name in SIZES:
        src_name = SIZE_TO_SRC.get(size_px)
        if not src_name:
            print(f"  skip {target_name} (no {size_px}px source)")
            continue
        src_path = os.path.join(ICON_SRC, src_name)
        if not os.path.isfile(src_path):
            print(f"  skip {target_name} (missing {src_path})")
            continue
        dst_path = os.path.join(iconset_dir, target_name)
        shutil.copy2(src_path, dst_path)

    try:
        subprocess.run(
            ["iconutil", "-c", "icns", iconset_dir, "-o", OUTPUT_ICNS],
            check=True,
        )
        print(f"Created {OUTPUT_ICNS}")
    finally:
        shutil.rmtree(iconset_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
