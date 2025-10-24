#!/usr/bin/env python3
"""
OS AI Desktop Launcher
Unified launcher that runs both backend (Python/FastAPI) and frontend (Flutter) together.
Provides system tray integration for easy show/hide and lifecycle management.
"""

import os
import sys
import glob
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
__version__ = "1.0.0"


class OSAILauncher:
    """Main launcher class that manages backend and frontend lifecycle"""

    def __init__(self):
        self.logger = self._setup_logging()
        self.backend_thread: Optional[threading.Thread] = None
        self.flutter_process: Optional[subprocess.Popen] = None
        self.is_running = True
        self.tray_icon: Optional[pystray.Icon] = None

        # Determine paths
        self.root_dir = _ROOT
        self.flutter_app_path = self._find_flutter_app()

        self.logger.info(f"OS AI Launcher v{__version__}")
        self.logger.info(f"Root dir: {self.root_dir}")
        self.logger.info(f"Flutter app: {self.flutter_app_path}")

    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(sys.stdout),
                logging.FileHandler(self.root_dir / "launcher.log" if hasattr(self, 'root_dir') else "launcher.log")
            ]
        )
        return logging.getLogger("os_ai.launcher")

    def _find_flutter_app(self) -> Optional[Path]:
        """Find Flutter application executable

        When bundled with PyInstaller, Flutter app should be in:
        - macOS: .app/Contents/Resources/flutter_app/
        - Windows: resources/flutter_app/
        - Linux: resources/flutter_app/

        For development, look in frontend_flutter/build/
        """
        system = platform.system()

        # Check if running from PyInstaller bundle
        if getattr(sys, 'frozen', False):
            bundle_dir = Path(sys._MEIPASS)  # type: ignore

            if system == "Darwin":
                # macOS: look in .app/Contents/Resources/
                app_path = bundle_dir.parent / "Resources" / "flutter_app"
                candidates = [
                    app_path / "macos" / "Runner.app" / "Contents" / "MacOS" / "Runner",
                    app_path / "OS AI.app" / "Contents" / "MacOS" / "OS AI",
                ]
            elif system == "Windows":
                app_path = bundle_dir / "resources" / "flutter_app"
                candidates = [
                    app_path / "build" / "windows" / "runner" / "Release" / "frontend_flutter.exe",
                    app_path / "OS_AI.exe",
                ]
            else:  # Linux
                app_path = bundle_dir / "resources" / "flutter_app"
                candidates = [
                    app_path / "build" / "linux" / "x64" / "release" / "bundle" / "frontend_flutter",
                    app_path / "os_ai",
                ]
        else:
            # Development mode - look in frontend_flutter/build/
            if system == "Darwin":
                candidates = [
                    self.root_dir / "frontend_flutter" / "build" / "macos" / "Build" / "Products" / "Release" / "frontend_flutter.app" / "Contents" / "MacOS" / "frontend_flutter",
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

    def start_backend(self):
        """Start the FastAPI backend server in a separate thread"""
        self.logger.info("Starting backend server...")

        def run_backend():
            try:
                # Set environment defaults
                os.environ.setdefault('OS_AI_BACKEND_HOST', '127.0.0.1')
                os.environ.setdefault('OS_AI_BACKEND_PORT', '8765')

                from os_ai_backend.app import main as backend_main
                backend_main()
            except Exception as e:
                self.logger.exception(f"Backend error: {e}")

        self.backend_thread = threading.Thread(target=run_backend, daemon=True)
        self.backend_thread.start()

        # Give backend time to start
        time.sleep(2)
        self.logger.info("Backend server started on http://127.0.0.1:8765")

    def start_flutter(self):
        """Start the Flutter application"""
        if not self.flutter_app_path:
            self.logger.error("Flutter app not found, cannot start")
            return

        self.logger.info(f"Starting Flutter app: {self.flutter_app_path}")

        try:
            self.flutter_process = subprocess.Popen(
                [str(self.flutter_app_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.logger.info(f"Flutter app started (PID: {self.flutter_process.pid})")
        except Exception as e:
            self.logger.exception(f"Failed to start Flutter app: {e}")

    def stop_all(self):
        """Stop backend and flutter gracefully"""
        self.logger.info("Stopping OS AI...")
        self.is_running = False

        # Stop Flutter
        if self.flutter_process:
            self.logger.info("Terminating Flutter app...")
            self.flutter_process.terminate()
            try:
                self.flutter_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.logger.warning("Flutter didn't terminate, killing...")
                self.flutter_process.kill()

        # Backend thread will stop when main process exits (daemon=True)
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

            # Start Flutter
            self.start_flutter()

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
