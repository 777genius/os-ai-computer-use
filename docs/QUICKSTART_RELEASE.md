# Quick Start: Creating a Release

## TL;DR

```bash
# 1. Bump version
echo "1.0.0" > VERSION

# 2. Commit and tag
git add VERSION
git commit -m "chore: bump version to 1.0.0"
git tag v1.0.0

# 3. Push
git push origin main && git push origin v1.0.0
```

That's it! GitHub Actions will:
- ✅ Build macOS app
- ✅ Build Windows app
- ✅ Build Linux app
- ✅ Build Web app
- ✅ Create GitHub Release with all artifacts

## Local Build (Before Release)

Test locally first:

```bash
# macOS
make build-desktop-macos

# Windows
make build-desktop-windows

# Linux
make build-desktop-linux

# Or use the universal script
python packaging/build_all.py
```

## What Gets Built

### For Users:
- **macOS**: `OS_AI_1.0.0_macOS.zip` (or .dmg)
- **Windows**: `OS_AI_1.0.0_Windows.zip`
- **Linux**: `OS_AI_1.0.0_Linux.tar.gz` (or .AppImage)
- **Web**: `OS_AI_1.0.0_Web.zip`

### What's Inside:
Each package contains:
- Flutter UI application
- Python backend (FastAPI)
- System tray launcher
- All dependencies bundled

## First Time Setup

1. **Permissions** (macOS only for local builds):
   ```bash
   make macos-perms
   ```

2. **Dependencies**:
   ```bash
   pip install -r requirements.txt
   cd frontend_flutter && flutter pub get
   ```

3. **Test**:
   ```bash
   python packaging/build_all.py
   ```

## Monitoring Releases

- Go to: `https://github.com/YOUR_USERNAME/os-ai-computer-use/actions`
- Watch the `Release` workflow
- When complete, check `Releases` page for artifacts

## Common Issues

**Q: Workflow didn't trigger**
A: Tag must start with `v` (e.g., `v1.0.0`, not `1.0.0`)

**Q: Build failed**
A: Check Actions logs, usually missing dependencies or Flutter not installed

**Q: Can I test without creating a tag?**
A: Yes! Build locally with `make build-desktop-macos` (or python script)

## Next Steps

See [RELEASE.md](./RELEASE.md) for:
- Detailed CI/CD documentation
- Troubleshooting guide
- Code signing setup
- Auto-updater configuration
