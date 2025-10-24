#!/usr/bin/env python3
"""
Script to generate simple tray icons for the application.
Creates PNG and ICO files with a simple robot icon.
"""

from PIL import Image, ImageDraw
import os


def create_tray_icon(size=64):
    """Create a simple tray icon"""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Scale factor
    s = size / 64.0

    # Draw robot head (rounded rectangle)
    draw.rounded_rectangle(
        [10*s, 10*s, 54*s, 54*s],
        radius=5*s,
        outline='black',
        width=int(2*s),
        fill='white'
    )

    # Eyes
    draw.ellipse([18*s, 22*s, 26*s, 30*s], fill='black')
    draw.ellipse([38*s, 22*s, 46*s, 30*s], fill='black')

    # Mouth
    draw.rectangle([22*s, 40*s, 42*s, 44*s], fill='black')

    # Antenna
    draw.line([32*s, 10*s, 32*s, 5*s], fill='black', width=int(2*s))
    draw.ellipse([29*s, 2*s, 35*s, 8*s], fill='black')

    return image


def main():
    # Create output directory
    output_dir = os.path.join(
        os.path.dirname(__file__),
        '..',
        'frontend_flutter',
        'assets',
        'icons'
    )
    os.makedirs(output_dir, exist_ok=True)

    # Create PNG icon (for macOS/Linux)
    print("Creating tray_icon.png...")
    png_icon = create_tray_icon(64)
    png_icon.save(os.path.join(output_dir, 'tray_icon.png'), 'PNG')

    # Create ICO icon (for Windows) - multiple sizes
    print("Creating tray_icon.ico...")
    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_images = [create_tray_icon(size) for size in ico_sizes]
    ico_images[0].save(
        os.path.join(output_dir, 'tray_icon.ico'),
        format='ICO',
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[1:]
    )

    print("✓ Icons created successfully!")
    print(f"  - {output_dir}/tray_icon.png")
    print(f"  - {output_dir}/tray_icon.ico")


if __name__ == '__main__':
    main()
