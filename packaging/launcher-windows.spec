# -*- mode: python ; coding: utf-8 -*-

import os

block_cipher = None

# Resolve project root
ROOT = os.path.abspath(os.getcwd())
LAUNCHER_SCRIPT = os.path.join(ROOT, 'launcher.py')

# Collect data files
datas = []

# Add Flutter app build (will be built by CI/CD before PyInstaller)
FLUTTER_APP = os.path.join(ROOT, 'frontend_flutter', 'build', 'windows', 'runner', 'Release')
if os.path.exists(FLUTTER_APP):
    # Bundle entire Flutter Release folder
    datas.append((FLUTTER_APP, 'flutter_app'))
    print(f"[OK] Including Flutter app: {FLUTTER_APP}")
else:
    print(f"[WARNING] Flutter app not found at: {FLUTTER_APP}")
    print("  You need to build Flutter first: cd frontend_flutter && flutter build windows --release")

# Bundle version file
VERSION_FILE = os.path.join(ROOT, 'VERSION')
if os.path.exists(VERSION_FILE):
    datas.append((VERSION_FILE, '.'))

hiddenimports = [
    # System tray
    'pystray', 'pystray._win32',
    # PyAutoGUI stack on Windows
    'pyautogui', 'pyscreeze', 'mouseinfo', 'pygetwindow', 'pytweening',
    'pyperclip',
    'PIL', 'PIL.Image', 'PIL.ImageFile', 'PIL.PngImagePlugin', 'PIL.JpegImagePlugin',
    # pywin32 helpers
    'win32api', 'win32con', 'win32gui', 'win32process', 'win32ui', 'pywintypes',
    # Backend
    'uvicorn', 'uvicorn.loops', 'uvicorn.loops.auto', 'uvicorn.protocols',
    'uvicorn.protocols.http', 'uvicorn.protocols.http.auto',
    'uvicorn.protocols.websockets', 'uvicorn.protocols.websockets.auto',
    'uvicorn.protocols.websockets.websockets_impl',
    'uvicorn.protocols.websockets.wsproto_impl',
    'uvicorn.lifespan', 'uvicorn.lifespan.on',
    'fastapi', 'starlette', 'starlette.routing', 'starlette.responses',
    'starlette.middleware', 'starlette.websockets',
    'pydantic', 'websockets', 'websockets.legacy', 'websockets.legacy.server',
    # DI container
    'injector',
    # Internal packages — top-level + key submodules
    'os_ai_core', 'os_ai_core.tools.computer', 'os_ai_core.config', 'os_ai_core.di',
    'os_ai_core.orchestrator', 'os_ai_core.tools.registry',
    'os_ai_core.utils.logger', 'os_ai_core.utils.conversation_optimizer',
    'os_ai_os', 'os_ai_os.api', 'os_ai_os.platform', 'os_ai_os.platform.factory',
    'os_ai_os.platform.drivers', 'os_ai_os.defaults', 'os_ai_os.config',
    'os_ai_os.ports', 'os_ai_os.ports.mouse', 'os_ai_os.ports.keyboard',
    'os_ai_os.ports.screen', 'os_ai_os.ports.overlay', 'os_ai_os.ports.sound',
    'os_ai_os.ports.permissions', 'os_ai_os.ports.types',
    'os_ai_os_windows', 'os_ai_os_windows.drivers',
    'os_ai_backend', 'os_ai_backend.app', 'os_ai_backend.config',
    'os_ai_backend.ws', 'os_ai_backend.security', 'os_ai_backend.files',
    'os_ai_backend.jobs', 'os_ai_backend.metrics', 'os_ai_backend.settings',
    'os_ai_backend.sessions',
    'os_ai_llm', 'os_ai_llm.config', 'os_ai_llm.interfaces', 'os_ai_llm.types',
    'os_ai_llm_anthropic', 'os_ai_llm_anthropic.adapters_anthropic', 'os_ai_llm_anthropic.config',
    'os_ai_llm_openai', 'os_ai_llm_openai.adapters_openai', 'os_ai_llm_openai.config',
    'os_ai_llm_openai.action_converter',
    # Provider clients + deps
    'anthropic', 'openai', 'httpx', 'httpcore', 'h11', 'sniffio', 'certifi', 'idna',
    'anyio',
]

a = Analysis(
    [LAUNCHER_SCRIPT],
    pathex=[
        ROOT,
        os.path.join(ROOT, 'packages', 'core', 'src'),
        os.path.join(ROOT, 'packages', 'os', 'src'),
        os.path.join(ROOT, 'packages', 'os-windows', 'src'),
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
    name='OS_AI',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,  # GUI application (no console window)
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # TODO: Add .ico icon
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
