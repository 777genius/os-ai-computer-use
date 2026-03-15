# -*- mode: python ; coding: utf-8 -*-

import os
import glob

block_cipher = None

# Resolve project root
ROOT = os.path.abspath(os.getcwd())
LAUNCHER_SCRIPT = os.path.join(ROOT, 'launcher.py')

# Collect data files
datas = []

# Flutter .app НЕ встраивается через PyInstaller Tree() — это кодирует точки
# как __dot__ и ломает структуру macOS бандлов (framework, app).
# Вместо этого Flutter .app копируется в Contents/Resources/ после сборки
# PyInstaller (см. CI workflow или Makefile).
FLUTTER_APP = os.path.join(ROOT, 'frontend_flutter', 'build', 'macos', 'Build', 'Products', 'Release', 'OS AI.app')
if os.path.exists(FLUTTER_APP):
    print(f"[OK] Flutter app found: {FLUTTER_APP}")
    print("     It will be copied to Resources/flutter_app/ AFTER PyInstaller build")
else:
    print(f"[WARNING] Flutter app not found at: {FLUTTER_APP}")
    print("  You need to build Flutter first: cd frontend_flutter && flutter build macos --release")

# Bundle macOS sound assets
SOUNDS_DIR = os.path.join(ROOT, 'packages', 'os-macos', 'src', 'os_ai_os_macos', 'assets', 'sounds')
if os.path.isdir(SOUNDS_DIR):
    for fname in os.listdir(SOUNDS_DIR):
        if fname.lower().endswith(('.mp3', '.wav', '.aiff')):
            src = os.path.join(SOUNDS_DIR, fname)
            datas.append((src, os.path.join('os_ai_os_macos', 'assets', 'sounds')))

# Bundle version file
VERSION_FILE = os.path.join(ROOT, 'VERSION')
if os.path.exists(VERSION_FILE):
    datas.append((VERSION_FILE, '.'))

hiddenimports = [
    # System tray
    'pystray', 'pystray._darwin',
    # macOS specific
    'Quartz', 'AppKit', 'Foundation', 'objc',
    # PyAutoGUI stack
    'pyautogui', 'pyscreeze', 'mouseinfo', 'pygetwindow', 'pytweening',
    'PIL', 'PIL.Image', 'PIL.ImageFile', 'PIL.PngImagePlugin', 'PIL.JpegImagePlugin',
    # Backend
    'uvicorn', 'uvicorn.loops', 'uvicorn.loops.auto', 'uvicorn.protocols',
    'uvicorn.protocols.http', 'uvicorn.protocols.http.auto', 'uvicorn.lifespan', 'uvicorn.lifespan.on',
    'fastapi', 'starlette', 'pydantic', 'websockets',
    # Internal packages
    'os_ai_core', 'os_ai_core.tools.computer', 'os_ai_os', 'os_ai_os_macos',
    'os_ai_backend', 'os_ai_backend.app',
    'os_ai_llm', 'os_ai_llm_anthropic', 'os_ai_llm_openai',
    # Provider clients
    'anthropic', 'httpx', 'anyio',
]

a = Analysis(
    [LAUNCHER_SCRIPT],
    pathex=[
        ROOT,
        os.path.join(ROOT, 'packages', 'core', 'src'),
        os.path.join(ROOT, 'packages', 'os', 'src'),
        os.path.join(ROOT, 'packages', 'os-macos', 'src'),
        os.path.join(ROOT, 'packages', 'backend', 'src'),
        os.path.join(ROOT, 'packages', 'llm', 'src'),
        os.path.join(ROOT, 'packages', 'llm_anthropic', 'src'),
        os.path.join(ROOT, 'packages', 'llm_openai', 'src'),
    ],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# Подпись: берём из env или используем identity из Keychain
CODESIGN_IDENTITY = os.environ.get(
    'APPLE_SIGNING_IDENTITY',
    'Developer ID Application: Oleksii Zelenko (6C84CW694S)'
)
ENTITLEMENTS = os.path.join(ROOT, 'packaging', 'entitlements.plist')

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='OS_AI',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,  # GUI application
    disable_windowed_traceback=False,
    target_arch=None,  # Build for current architecture (GitHub Actions runners)
    codesign_identity=CODESIGN_IDENTITY,
    entitlements_file=ENTITLEMENTS,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    name='OS_AI'
)

app = BUNDLE(
    coll,
    name='OS AI.app',
    icon=None,  # TODO: Add .icns icon
    bundle_identifier='com.osai.desktop',
    version=os.environ.get('APP_VERSION', '1.0.0'),
    info_plist={
        'NSPrincipalClass': 'NSApplication',
        'NSHighResolutionCapable': 'True',
        'LSUIElement': '0',  # Show in Dock
        'LSMinimumSystemVersion': '10.15',

        # Privacy / разрешения macOS (обязательны для Gatekeeper)
        'NSScreenCaptureUsageDescription':
            'OS AI needs screen recording access to capture screenshots for AI-assisted automation.',
        'NSAppleEventsUsageDescription':
            'OS AI needs to control your computer to perform automation tasks.',
        'NSSystemAdministrationUsageDescription':
            'OS AI needs system access for automation.',
        'NSAccessibilityUsageDescription':
            'OS AI needs accessibility access to control mouse and keyboard for automation tasks.',
        'NSMicrophoneUsageDescription':
            'OS AI may use the microphone for voice input features.',
        'NSCameraUsageDescription':
            'OS AI may use the camera for visual tasks.',
    },
)
