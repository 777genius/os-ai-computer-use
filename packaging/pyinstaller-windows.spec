# -*- mode: python ; coding: utf-8 -*-

import os

# We invoke PyInstaller from project root (see Makefile). Resolve entry and paths here.
ROOT = os.path.abspath(os.getcwd())
SCRIPT = os.path.join(ROOT, 'main.py')

datas = []

hiddenimports = [
    # internal modules
    'os_ai_core', 'os_ai_core.tools.computer', 'os_ai_os', 'os_ai_os_windows', 'os_ai_cli',
    'os_ai_llm', 'os_ai_llm_anthropic', 'os_ai_llm_openai',
    # provider clients
    'anthropic', 'httpx', 'anyio', 'pydantic',
    # pyautogui stack on Windows
    'pyautogui', 'pyscreeze', 'mouseinfo', 'pygetwindow', 'pytweening',
    'PIL', 'PIL.Image', 'PIL.ImageFile', 'PIL.PngImagePlugin', 'PIL.JpegImagePlugin',
    # pywin32 helpers (usually auto-detected by hooks, list for safety)
    'win32api', 'win32con', 'win32gui', 'win32process', 'win32ui', 'pywintypes',
]

a = Analysis(
    [SCRIPT],
    pathex=[
        ROOT,
        os.path.join(ROOT, 'packages', 'core', 'src'),
        os.path.join(ROOT, 'packages', 'os', 'src'),
        os.path.join(ROOT, 'packages', 'os-windows', 'src'),
        os.path.join(ROOT, 'packages', 'cli', 'src'),
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
    cipher=None,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=None)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='agent_core',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
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
    name='agent_core'
)


