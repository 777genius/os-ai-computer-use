# OS AI Desktop - Release & CI/CD Guide

## Overview

This document describes the release process and CI/CD setup for OS AI Desktop application.

## Architecture

OS AI Desktop is a unified application that combines:
- **Python Backend**: FastAPI server running in background
- **Flutter Frontend**: Cross-platform UI application
- **Launcher**: Python script that starts both components and provides system tray integration

The application is packaged into a single executable for each platform using PyInstaller.

## Platforms

The CI/CD system builds for the following platforms:

- **macOS** (Intel + Apple Silicon): `.app` bundle and `.dmg` installer
- **Windows** (x64): `.exe` with installer
- **Linux** (x64): `.tar.gz` and `.AppImage` (if available)
- **Web**: Static files for deployment to GitHub Pages

## Versioning

Version is managed in the `VERSION` file at the project root.

Format: `MAJOR.MINOR.PATCH` (semantic versioning)

Example: `1.0.0`

## Release Process

### Automated Release (Recommended)

Releases are automatically created when you push a git tag:

```bash
# 1. Update VERSION file
echo "1.0.0" > VERSION

# 2. Commit the version bump
git add VERSION
git commit -m "chore: bump version to 1.0.0"

# 3. Create and push tag
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

This will:
1. Trigger the `release.yml` workflow
2. Build all platforms in parallel (macOS, Windows, Linux, Web)
3. Create a GitHub Release with all artifacts
4. Generate changelog from git commits

### Manual Build (Local Development)

#### macOS

```bash
make build-desktop-macos
# Output: dist/OS AI.app
```

#### Windows

```bash
make build-desktop-windows
# Output: dist/OS_AI/
```

#### Linux

```bash
make build-desktop-linux
# Output: dist/os_ai/
```

#### All Platforms (using build script)

```bash
python packaging/build_all.py

# Options:
python packaging/build_all.py --no-clean        # Skip clean step
python packaging/build_all.py --flutter-only    # Build Flutter only
python packaging/build_all.py --package-only    # Package only (skip Flutter build)
```

## GitHub Actions Workflows

### Main Workflows

1. **`ci.yml`**: Runs tests on every push/PR
   - Python unit tests on macOS and Windows
   - No GUI integration tests in CI (run locally)

2. **`release.yml`**: Creates releases on git tags
   - Extracts version from tag (e.g., `v1.0.0` → `1.0.0`)
   - Calls all platform build workflows in parallel
   - Creates GitHub Release with artifacts and changelog

### Platform Build Workflows

3. **`build-macos.yml`**: Builds macOS application
   - Builds Flutter macOS app
   - Packages with PyInstaller (Universal binary for Intel + Apple Silicon)
   - Creates `.zip` and `.dmg` (if create-dmg available)

4. **`build-windows.yml`**: Builds Windows application
   - Builds Flutter Windows app
   - Packages with PyInstaller
   - Creates `.zip` archive

5. **`build-linux.yml`**: Builds Linux application
   - Builds Flutter Linux app
   - Packages with PyInstaller
   - Creates `.tar.gz` and `.AppImage` (if appimagetool available)

6. **`build-web.yml`**: Builds Web application
   - Builds Flutter Web app
   - Creates `.zip` archive
   - Optionally deploys to GitHub Pages on release

## Build Artifacts

After a successful release, the following artifacts are available in GitHub Releases:

### macOS
- `OS_AI_{version}_macOS.zip` - Compressed .app bundle
- `OS_AI_{version}_macOS.dmg` - DMG installer (if available)

### Windows
- `OS_AI_{version}_Windows.zip` - Compressed executable folder

### Linux
- `OS_AI_{version}_Linux.tar.gz` - Compressed executable folder
- `OS_AI_{version}_Linux.AppImage` - Portable AppImage (if available)

### Web
- `OS_AI_{version}_Web.zip` - Static files for web hosting

## Auto-Updater

The Flutter application includes an auto-updater that:
1. Checks GitHub Releases API for latest version
2. Compares with current version (from `package_info_plus`)
3. Shows update banner if new version available
4. Opens download URL in browser when user clicks "Download"

### Configuring Auto-Updater

Update the repository info in `frontend_flutter/lib/src/app/services/auto_updater_service.dart`:

```dart
static const String _owner = 'your-github-username';
static const String _repo = 'your-repo-name';
```

## System Tray Integration

The launcher provides system tray functionality:

**macOS/Windows/Linux**:
- Click tray icon: Show/hide window
- Right-click: Context menu
  - Show Window
  - Check for Updates
  - Quit OS AI

The tray icons are located in `frontend_flutter/assets/icons/`:
- `tray_icon.png` - For macOS/Linux
- `tray_icon.ico` - For Windows

## Troubleshooting

### Build Failures

**Flutter not found**:
```bash
# Install Flutter
brew install flutter  # macOS
# OR
# Download from https://flutter.dev
```

**PyInstaller errors**:
```bash
# Reinstall PyInstaller
pip uninstall pyinstaller
pip install pyinstaller

# Clean previous builds
rm -rf build dist
```

**Missing dependencies**:
```bash
# macOS
brew install create-dmg  # For DMG creation

# Linux
sudo apt-get install libgtk-3-dev libappindicator3-dev
```

### Release Failures

**Workflow not triggered**:
- Ensure tag follows `v*.*.*` format (e.g., `v1.0.0`)
- Check GitHub Actions permissions (Settings → Actions → General)

**Artifact upload failed**:
- Check artifact size (< 2GB per artifact)
- Verify file paths in workflow

### Local Testing

Test the release workflow locally before pushing:

```bash
# 1. Build all platforms
python packaging/build_all.py

# 2. Verify artifacts
ls -lh dist/

# 3. Test the application
# macOS
open "dist/OS AI.app"

# Windows
dist/OS_AI/OS_AI.exe

# Linux
./dist/os_ai/os_ai
```

## Best Practices

1. **Version Bumps**: Always update `VERSION` file before creating a tag
2. **Changelog**: Write descriptive commit messages (used for auto-generated changelog)
3. **Testing**: Test locally before creating a release tag
4. **Permissions**: Ensure GitHub Actions has `contents: write` permission for releases
5. **Secrets**: Store API keys in GitHub Secrets, not in code

## Next Steps

After setting up CI/CD:

1. **Code Signing** (Optional but recommended):
   - macOS: Add Developer ID certificate to GitHub Secrets
   - Windows: Add code signing certificate

2. **Notarization** (macOS):
   - Required for distribution outside App Store
   - Add Apple ID and app-specific password to GitHub Secrets

3. **Auto-Update Implementation**:
   - Consider using Sparkle (macOS) or Squirrel (Windows) for seamless updates
   - Current implementation opens browser for download

4. **Analytics** (Optional):
   - Add telemetry to track update adoption
   - Monitor release download statistics

## Support

For issues with:
- **CI/CD**: Check GitHub Actions logs
- **Builds**: See build script output in `packaging/build_all.py`
- **Flutter**: Run `flutter doctor` for diagnostics
- **PyInstaller**: Check `build/` folder for detailed logs

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PyInstaller Documentation](https://pyinstaller.org/)
- [Flutter Build Documentation](https://docs.flutter.dev/deployment)
- [Semantic Versioning](https://semver.org/)
