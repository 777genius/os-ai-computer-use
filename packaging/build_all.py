#!/usr/bin/env python3
"""
Universal build script for OS AI Desktop
Builds Flutter app and packages it with Python backend into single executable.
"""

import os
import sys
import platform
import subprocess
import shutil
import argparse
from pathlib import Path


class Builder:
    def __init__(self, root_dir: Path):
        self.root = root_dir
        self.system = platform.system()
        self.flutter_dir = root_dir / "frontend_flutter"
        self.packaging_dir = root_dir / "packaging"
        self.dist_dir = root_dir / "dist"

    def log(self, msg: str):
        print(f"[BUILD] {msg}")

    def run_cmd(self, cmd: list, cwd: Path = None, check=True):
        """Run command and return result"""
        self.log(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, cwd=cwd or self.root, check=check)
        return result.returncode == 0

    def clean(self):
        """Clean previous builds"""
        self.log("Cleaning previous builds...")

        # Clean Flutter build
        if (self.flutter_dir / "build").exists():
            shutil.rmtree(self.flutter_dir / "build")

        # Clean PyInstaller dist
        if self.dist_dir.exists():
            shutil.rmtree(self.dist_dir)

        # Clean PyInstaller build cache
        if (self.root / "build").exists():
            shutil.rmtree(self.root / "build")

        self.log("✓ Clean complete")

    def install_dependencies(self):
        """Install Python dependencies"""
        self.log("Installing Python dependencies...")
        self.run_cmd([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        self.run_cmd([sys.executable, "-m", "pip", "install", "pyinstaller"])
        self.log("✓ Dependencies installed")

    def build_flutter(self):
        """Build Flutter application for current platform"""
        self.log(f"Building Flutter app for {self.system}...")

        if self.system == "Darwin":
            platform_arg = "macos"
        elif self.system == "Windows":
            platform_arg = "windows"
        elif self.system == "Linux":
            platform_arg = "linux"
        else:
            raise RuntimeError(f"Unsupported platform: {self.system}")

        # Run flutter pub get
        self.run_cmd(["flutter", "pub", "get"], cwd=self.flutter_dir)

        # Build release
        self.run_cmd(
            ["flutter", "build", platform_arg, "--release"],
            cwd=self.flutter_dir
        )

        self.log(f"✓ Flutter app built for {platform_arg}")

    def package_pyinstaller(self):
        """Package with PyInstaller"""
        self.log(f"Packaging with PyInstaller for {self.system}...")

        # Select appropriate spec file
        if self.system == "Darwin":
            spec_file = "launcher-macos.spec"
        elif self.system == "Windows":
            spec_file = "launcher-windows.spec"
        elif self.system == "Linux":
            spec_file = "launcher-linux.spec"
        else:
            raise RuntimeError(f"Unsupported platform: {self.system}")

        spec_path = self.packaging_dir / spec_file

        if not spec_path.exists():
            raise FileNotFoundError(f"Spec file not found: {spec_path}")

        # Run PyInstaller
        self.run_cmd(
            [sys.executable, "-m", "PyInstaller", str(spec_path), "--clean"],
            cwd=self.root
        )

        self.log("✓ PyInstaller packaging complete")

    def create_dmg(self):
        """Create DMG installer for macOS (requires create-dmg)"""
        if self.system != "Darwin":
            return

        self.log("Creating DMG installer...")

        app_path = self.dist_dir / "OS AI.app"
        if not app_path.exists():
            self.log("⚠ App bundle not found, skipping DMG creation")
            return

        dmg_path = self.dist_dir / "OS_AI.dmg"

        # Check if create-dmg is installed
        try:
            subprocess.run(["create-dmg", "--version"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.log("⚠ create-dmg not installed. Install with: brew install create-dmg")
            return

        # Remove old DMG if exists
        if dmg_path.exists():
            dmg_path.unlink()

        # Create DMG
        self.run_cmd([
            "create-dmg",
            "--volname", "OS AI",
            "--window-pos", "200", "120",
            "--window-size", "800", "400",
            "--icon-size", "100",
            "--app-drop-link", "600", "185",
            str(dmg_path),
            str(app_path)
        ], check=False)

        if dmg_path.exists():
            self.log(f"✓ DMG created: {dmg_path}")
        else:
            self.log("⚠ DMG creation failed")

    def create_zip(self):
        """Create ZIP archive for distribution"""
        self.log("Creating ZIP archive...")

        if self.system == "Darwin":
            app_name = "OS AI.app"
            zip_name = "OS_AI_macOS.zip"
        elif self.system == "Windows":
            app_name = "OS_AI"
            zip_name = "OS_AI_Windows.zip"
        elif self.system == "Linux":
            app_name = "os_ai"
            zip_name = "OS_AI_Linux.zip"
        else:
            return

        source = self.dist_dir / app_name
        if not source.exists():
            self.log(f"⚠ Build output not found: {source}")
            return

        # Create zip
        zip_path = self.dist_dir / zip_name
        if zip_path.exists():
            zip_path.unlink()

        shutil.make_archive(
            str(zip_path.with_suffix('')),
            'zip',
            self.dist_dir,
            app_name
        )

        self.log(f"✓ ZIP created: {zip_path}")

    def build_all(self, clean=True):
        """Run complete build pipeline"""
        self.log("=" * 60)
        self.log(f"OS AI Desktop Build - {self.system}")
        self.log("=" * 60)

        try:
            if clean:
                self.clean()

            self.install_dependencies()
            self.build_flutter()
            self.package_pyinstaller()

            # Platform-specific packaging
            if self.system == "Darwin":
                self.create_dmg()

            self.create_zip()

            self.log("=" * 60)
            self.log("✓ BUILD COMPLETE!")
            self.log(f"Output directory: {self.dist_dir}")
            self.log("=" * 60)

        except Exception as e:
            self.log(f"✗ BUILD FAILED: {e}")
            raise


def main():
    parser = argparse.ArgumentParser(description="Build OS AI Desktop")
    parser.add_argument("--no-clean", action="store_true", help="Skip clean step")
    parser.add_argument("--flutter-only", action="store_true", help="Build Flutter only")
    parser.add_argument("--package-only", action="store_true", help="Package with PyInstaller only (skip Flutter build)")

    args = parser.parse_args()

    root = Path(__file__).parent.parent.absolute()
    builder = Builder(root)

    try:
        if args.flutter_only:
            builder.build_flutter()
        elif args.package_only:
            builder.package_pyinstaller()
            if builder.system == "Darwin":
                builder.create_dmg()
            builder.create_zip()
        else:
            builder.build_all(clean=not args.no_clean)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
