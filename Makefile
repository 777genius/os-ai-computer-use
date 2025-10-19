PY?=$(shell which python)
PIP?=$(shell which pip)

.PHONY: venv install lint test unit itest itest-local keyboard click macos-perms macos-open-accessibility macos-open-input-monitoring macos-open-screen-recording dev-install build-macos-bundle build-windows-bundle

venv:
	@echo "(optional) manage your venv outside Makefile"

install:
	$(PY) -m pip install -r requirements.txt

dev-install:
	# Install local packages in editable mode for mono-repo dev
	$(PY) -m pip install -e packages/os
	$(PY) -m pip install -e packages/os-macos
	$(PY) -m pip install -e packages/os-windows
	$(PY) -m pip install -e packages/core
	$(PY) -m pip install -e packages/backend

lint:
	pytest -q -k "not integration_os"

test unit:
	pytest -q tests/unit

# Integration OS tests (macOS GUI). Requires Accessibility permissions.
itest:
	RUN_CURSOR_TESTS=1 pytest -q -s tests/integration

# Run OS harness manually without pytest
itest-local-keyboard:
	$(PY) -m utils.os_runner keyboard || true

itest-local-click:
	$(PY) -m utils.os_runner click || true

# Open macOS privacy panes for granting permissions
macos-open-accessibility:
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

macos-open-input-monitoring:
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

macos-open-screen-recording:
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

macos-perms: macos-open-accessibility macos-open-input-monitoring macos-open-screen-recording

build-macos-bundle:
	# Build single-file CLI for macOS using PyInstaller
	$(PY) -m pip install pyinstaller
	$(PY) -m PyInstaller packaging/pyinstaller-macos.spec
	@echo "Bundle at: dist/agent_core/agent_core"

build-windows-bundle:
	# Build CLI bundle for Windows (run on Windows host/runner)
	$(PY) -m pip install pyinstaller pywin32
	$(PY) -m PyInstaller packaging/pyinstaller-windows.spec
	@echo "Bundle at: dist/agent_core/agent_core.exe"


