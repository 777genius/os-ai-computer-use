# -*- mode: python ; coding: utf-8 -*-

import os

block_cipher = None

# Resolve project root
ROOT = os.path.abspath(os.getcwd())
LAUNCHER_SCRIPT = os.path.join(ROOT, 'launcher.py')

# Collect data files
datas = []

# Add Flutter app build (will be built by CI/CD before PyInstaller)
FLUTTER_APP = os.path.join(ROOT, 'frontend_flutter', 'build', 'linux', 'x64', 'release', 'bundle')
if os.path.exists(FLUTTER_APP):
    # Bundle entire Flutter bundle folder
    datas.append((FLUTTER_APP, 'flutter_app'))
    print(f"✓ Including Flutter app: {FLUTTER_APP}")
else:
    print(f"⚠ Flutter app not found at: {FLUTTER_APP}")
    print("  You need to build Flutter first: cd frontend_flutter && flutter build linux --release")

# Bundle version file
VERSION_FILE = os.path.join(ROOT, 'VERSION')
if os.path.exists(VERSION_FILE):
    datas.append((VERSION_FILE, '.'))

hiddenimports = [
    # System tray
    'pystray', 'pystray._gtk',
    # PyAutoGUI stack
    'pyautogui', 'pyscreeze', 'mouseinfo', 'pygetwindow', 'pytweening',
    'PIL', 'PIL.Image', 'PIL.ImageFile', 'PIL.PngImagePlugin', 'PIL.JpegImagePlugin',
    # Backend
    'uvicorn', 'uvicorn.loops', 'uvicorn.loops.auto', 'uvicorn.protocols',
    'uvicorn.protocols.http', 'uvicorn.protocols.http.auto', 'uvicorn.lifespan', 'uvicorn.lifespan.on',
    'fastapi', 'starlette', 'pydantic', 'websockets',
    # Internal packages
    'os_ai_core', 'os_ai_core.tools.computer', 'os_ai_os', 'os_ai_os_linux',
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

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='os_ai',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,  # GUI application
    disable_windowed_traceback=False,
    target_arch=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    name='os_ai'
)
