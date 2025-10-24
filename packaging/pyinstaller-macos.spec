# -*- mode: python ; coding: utf-8 -*-

import os

block_cipher = None

# Collect package assets (sounds, etc.)
datas = []

# Resolve project root (we run PyInstaller from project root via Makefile)
ROOT = os.path.abspath(os.getcwd())
SCRIPT = os.path.join(ROOT, 'main.py')

# Bundle macOS sound assets explicitly (path within repo)
SOUNDS_DIR = os.path.join(ROOT, 'packages', 'os-macos', 'src', 'os_ai_os_macos', 'assets', 'sounds')
if os.path.isdir(SOUNDS_DIR):
    for fname in os.listdir(SOUNDS_DIR):
        if fname.lower().endswith(('.mp3', '.wav', '.aiff')):
            src = os.path.join(SOUNDS_DIR, fname)
            # place into relative dir inside bundle
            datas.append((src, os.path.join('os_ai_os_macos', 'assets', 'sounds')))

hiddenimports = [
    'Quartz', 'AppKit', 'Foundation', 'objc',
    'pyautogui', 'pyscreeze', 'mouseinfo', 'pygetwindow', 'pytweening',
    'PIL', 'PIL.Image', 'PIL.ImageFile', 'PIL.PngImagePlugin', 'PIL.JpegImagePlugin',
    # internal packages that may be resolved via dynamic sys.path in main.py
    'os_ai_core', 'os_ai_core.tools.computer', 'os_ai_os', 'os_ai_os_macos', 'os_ai_cli',
    'os_ai_llm', 'os_ai_llm_anthropic', 'os_ai_llm_openai',
    # provider clients
    'anthropic', 'httpx', 'anyio', 'pydantic',
]

a = Analysis(
    [SCRIPT],
    pathex=[
        ROOT,
        os.path.join(ROOT, 'packages', 'core', 'src'),
        os.path.join(ROOT, 'packages', 'os', 'src'),
        os.path.join(ROOT, 'packages', 'os-macos', 'src'),
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
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

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


