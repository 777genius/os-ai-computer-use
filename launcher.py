#!/usr/bin/env python3
"""
OS AI Desktop Launcher
Unified launcher that runs both backend (Python/FastAPI) and frontend (Flutter) together.
Provides system tray integration for easy show/hide and lifecycle management.
"""

import os
import sys
import glob
import socket
import subprocess
import threading
import logging
import signal
import time
import platform
from pathlib import Path
from typing import Optional

import pystray
from PIL import Image, ImageDraw


# Ensure all workspace package sources are importable
_ROOT = Path(__file__).parent.absolute()
for _src_dir in glob.glob(str(_ROOT / "packages" / "*" / "src")):
    if _src_dir not in sys.path:
        sys.path.insert(0, _src_dir)


# Version info
__version__ = "1.1.0"


class OSAILauncher:
    """Main launcher class that manages backend and frontend lifecycle"""

    def __init__(self):
        self.root_dir = _ROOT
        self.log_dir = self._get_log_dir()
        self.logger = self._setup_logging()
        self.backend_thread: Optional[threading.Thread] = None
        self.flutter_process: Optional[subprocess.Popen] = None
        self.is_running = True
        self.tray_icon: Optional[pystray.Icon] = None

        # Threading events for lifecycle management
        self.shutdown_event = threading.Event()
        self.backend_started = threading.Event()

        # Determine paths
        self.flutter_app_path = self._find_flutter_app()

        self.logger.info(f"OS AI Launcher v{__version__}")
        self.logger.info(f"Root dir: {self.root_dir}")
        self.logger.info(f"Flutter app: {self.flutter_app_path}")

        if platform.system() == "Linux":
            self._check_linux_deps()

    def _check_linux_deps(self):
        """Check Linux system dependencies and log warnings for missing ones."""
        import shutil
        missing = []
        for tool, purpose in [
            ("scrot", "screenshots"),
            ("xdotool", "window management"),
            ("xclip", "clipboard"),
        ]:
            if not shutil.which(tool):
                missing.append(f"{tool} ({purpose})")
        if missing:
            self.logger.warning(
                "Missing Linux system tools: %s. "
                "Install with: sudo apt-get install %s",
                ", ".join(missing),
                " ".join(t.split()[0] for t in missing),
            )
        if not os.environ.get("DISPLAY"):
            if os.environ.get("WAYLAND_DISPLAY"):
                self.logger.error(
                    "Wayland detected but no X11 display (DISPLAY not set). "
                    "OS AI requires XWayland. Enable it in your compositor settings."
                )
            else:
                self.logger.error(
                    "No display server found (DISPLAY not set). "
                    "OS AI requires an X11 display to control the desktop."
                )

    def _get_log_dir(self) -> Path:
        """Return a writable directory for log files.

        On macOS: ~/Library/Logs/OS AI/
        On Linux: ~/.local/share/os-ai/
        On Windows: %LOCALAPPDATA%/OS AI/
        Falls back to a temp directory if nothing else works.
        """
        system = platform.system()
        try:
            if system == "Darwin":
                log_dir = Path.home() / "Library" / "Logs" / "OS AI"
            elif system == "Windows":
                local = os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
                log_dir = Path(local) / "OS AI" / "logs"
            else:
                log_dir = Path.home() / ".local" / "share" / "os-ai" / "logs"
            log_dir.mkdir(parents=True, exist_ok=True)
            return log_dir
        except OSError:
            import tempfile
            return Path(tempfile.gettempdir())

    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        log_file = self.log_dir / "launcher.log"
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(sys.stdout),
                logging.FileHandler(log_file),
            ]
        )
        return logging.getLogger("os_ai.launcher")

    def _find_flutter_app(self) -> Optional[Path]:
        """Find Flutter application executable

        When bundled with PyInstaller, Flutter app is in:
        - All platforms: _MEIPASS/flutter_app/ (PyInstaller temp extraction directory)

        For development, look in frontend_flutter/build/
        """
        system = platform.system()

        # Check if running from PyInstaller bundle
        if getattr(sys, 'frozen', False):
            if system == "Darwin":
                # macOS: Flutter .app копируется в Contents/Resources/flutter_app/
                # (не через PyInstaller Tree, чтобы сохранить структуру бандлов)
                bundle_dir = Path(sys.executable).parent.parent  # Contents/
                app_path = bundle_dir / "Resources" / "flutter_app"
            else:
                # Windows/Linux: PyInstaller extracts data files to _MEIPASS
                bundle_dir = Path(sys._MEIPASS)  # type: ignore
                app_path = bundle_dir / "flutter_app"

            if system == "Darwin":
                # macOS: flutter_app/OS AI.app/Contents/MacOS/OS AI
                candidates = [
                    app_path / "OS AI.app" / "Contents" / "MacOS" / "OS AI",
                ]
            elif system == "Windows":
                # Windows: spec bundles entire Release folder to flutter_app/
                candidates = [
                    app_path / "frontend_flutter.exe",
                ]
            else:  # Linux
                # Linux: spec bundles entire bundle folder to flutter_app/
                candidates = [
                    app_path / "frontend_flutter",
                ]
        else:
            # Development mode - look in frontend_flutter/build/
            if system == "Darwin":
                candidates = [
                    self.root_dir / "frontend_flutter" / "build" / "macos" / "Build" / "Products" / "Release" / "OS AI.app" / "Contents" / "MacOS" / "OS AI",
                ]
            elif system == "Windows":
                candidates = [
                    self.root_dir / "frontend_flutter" / "build" / "windows" / "runner" / "Release" / "frontend_flutter.exe",
                ]
            else:  # Linux
                candidates = [
                    self.root_dir / "frontend_flutter" / "build" / "linux" / "x64" / "release" / "bundle" / "frontend_flutter",
                ]

        for candidate in candidates:
            if candidate.exists():
                return candidate

        self.logger.warning(f"Flutter app not found. Searched: {candidates}")
        return None

    def _create_tray_icon(self) -> Image.Image:
        """Create a simple tray icon (robot emoji or basic shape)"""
        # Create a simple 64x64 icon
        width = 64
        height = 64
        image = Image.new('RGB', (width, height), 'white')
        dc = ImageDraw.Draw(image)

        # Draw a simple robot face
        # Head
        dc.rectangle([10, 10, 54, 54], outline='black', width=2)
        # Eyes
        dc.ellipse([18, 22, 26, 30], fill='black')
        dc.ellipse([38, 22, 46, 30], fill='black')
        # Mouth
        dc.rectangle([22, 40, 42, 44], fill='black')

        return image

    def _wait_for_port(self, host: str, port: int, timeout: float = 15.0) -> bool:
        """Poll until the given TCP port accepts connections."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                with socket.create_connection((host, port), timeout=0.5):
                    return True
            except OSError:
                time.sleep(0.2)
        return False

    def start_backend(self):
        """Start the FastAPI backend server in a separate thread"""
        self.logger.info("Starting backend server...")

        # Check for API key configuration
        has_anthropic_key = bool(os.environ.get('ANTHROPIC_API_KEY'))
        has_openai_key = bool(os.environ.get('OPENAI_API_KEY'))

        if not has_anthropic_key:
            self.logger.info("No ANTHROPIC_API_KEY in environment - API key will be provided by frontend")
        else:
            self.logger.info("ANTHROPIC_API_KEY found in environment variables")

        host = os.environ.get('OS_AI_BACKEND_HOST', '127.0.0.1')
        port = int(os.environ.get('OS_AI_BACKEND_PORT', '8765'))

        def run_backend():
            try:
                # Set environment defaults
                os.environ.setdefault('OS_AI_BACKEND_HOST', host)
                os.environ.setdefault('OS_AI_BACKEND_PORT', str(port))

                from os_ai_backend.app import main as backend_main

                backend_main()
            except Exception as e:
                self.logger.exception(f"Backend error: {e}")

        self.backend_thread = threading.Thread(target=run_backend, daemon=True)
        self.backend_thread.start()

        # Wait for the port to actually become available
        self.logger.info(f"Waiting for backend on {host}:{port}...")
        if self._wait_for_port(host, port, timeout=15.0):
            self.backend_started.set()
            self.logger.info(f"Backend server ready on http://{host}:{port}")
        else:
            self.logger.error(f"Backend failed to start within 15 seconds (port {port} not listening)")

    def start_flutter(self):
        """Start the Flutter application"""
        if not self.flutter_app_path:
            self.logger.error("Flutter app not found, cannot start")
            return

        # Check if backend is running
        if not self.backend_started.is_set():
            self.logger.error("Backend is not running, cannot start Flutter")
            return

        self.logger.info(f"Starting Flutter app: {self.flutter_app_path}")

        try:
            self.flutter_process = subprocess.Popen(
                [str(self.flutter_app_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.logger.info(f"Flutter app started (PID: {self.flutter_process.pid})")

            # Monitor Flutter process in background
            def _monitor():
                proc = self.flutter_process
                if not proc:
                    return
                # Log stderr
                try:
                    for line in proc.stderr:  # type: ignore[union-attr]
                        text = line.decode("utf-8", errors="replace").rstrip()
                        if text:
                            self.logger.warning(f"Flutter stderr: {text}")
                except Exception:
                    pass
                # Process ended — log exit code
                rc = proc.wait()
                if rc != 0 and self.is_running:
                    self.logger.error(f"Flutter exited unexpectedly (code {rc})")

            threading.Thread(target=_monitor, daemon=True).start()

        except Exception as e:
            self.logger.exception(f"Failed to start Flutter app: {e}")

    def stop_all(self):
        """Stop backend and flutter gracefully"""
        self.logger.info("Stopping OS AI...")
        self.is_running = False

        # Signal backend to shutdown
        self.shutdown_event.set()

        # Stop Flutter first
        if self.flutter_process:
            self.logger.info("Terminating Flutter app...")
            self.flutter_process.terminate()
            try:
                self.flutter_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.logger.warning("Flutter didn't terminate, killing...")
                self.flutter_process.kill()

        # Give backend thread a moment to gracefully close connections
        if self.backend_thread and self.backend_thread.is_alive():
            self.logger.info("Waiting for backend to shutdown gracefully...")
            self.backend_thread.join(timeout=3)
            if self.backend_thread.is_alive():
                self.logger.warning("Backend didn't shutdown gracefully, will be terminated")

        self.logger.info("Shutdown complete")

    def on_quit(self, icon, item):
        """Tray menu: Quit action"""
        self.logger.info("Quit requested from tray")
        icon.stop()
        self.stop_all()

    def on_show(self, icon, item):
        """Tray menu: Show window action"""
        self.logger.info("Show window requested (handled by Flutter)")
        # Flutter app handles window show/hide via hotkeys
        # We could send a signal to Flutter here if needed

    def create_tray_menu(self):
        """Create system tray menu"""
        return pystray.Menu(
            pystray.MenuItem("OS AI", lambda: None, enabled=False),
            pystray.MenuItem("Show Window", self.on_show),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", self.on_quit),
        )

    def setup_tray(self):
        """Setup system tray icon"""
        icon_image = self._create_tray_icon()
        self.tray_icon = pystray.Icon(
            "os_ai",
            icon_image,
            "OS AI",
            menu=self.create_tray_menu()
        )

    def run(self):
        """Main run method - starts everything"""
        # Setup signal handlers for graceful shutdown
        def signal_handler(signum, frame):
            self.logger.info(f"Received signal {signum}")
            if self.tray_icon:
                self.tray_icon.stop()
            self.stop_all()
            sys.exit(0)

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        try:
            # Start backend
            self.start_backend()

            # Check if backend started successfully
            if not self.backend_started.is_set():
                self.logger.error("Failed to start backend. Exiting.")
                sys.exit(1)

            # Start Flutter
            self.start_flutter()

            # Check if Flutter started successfully
            if self.flutter_process is None:
                self.logger.error("Failed to start Flutter. Exiting.")
                sys.exit(1)

            # Setup and run tray (blocking call)
            self.setup_tray()
            self.logger.info("Starting system tray...")
            self.tray_icon.run()

        except KeyboardInterrupt:
            self.logger.info("Interrupted by user")
        except Exception as e:
            self.logger.exception(f"Fatal error: {e}")
        finally:
            self.stop_all()


def main():
    """Entry point"""
    launcher = OSAILauncher()
    launcher.run()


if __name__ == "__main__":
    main()
