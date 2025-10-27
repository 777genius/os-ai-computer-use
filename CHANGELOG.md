# Changelog

All notable changes to OS AI Computer Use will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-10-26

### Fixed

#### Production Build Issues
- **Fixed Flutter app not launching in production build**
  - Updated `launcher.py` to search for correct Flutter app name: `OS AI.app` instead of `frontend_flutter.app`
  - Updated `packaging/launcher-macos.spec` to bundle Flutter app using `Tree()` method
  - This preserves the `.app` bundle structure and prevents PyInstaller from processing executables as binaries
  - Affects both production (PyInstaller bundle) and development modes
  - Files: `launcher.py:86-104`, `packaging/launcher-macos.spec:16-85`

#### Impact
- Production builds (`dist/OS AI.app`) now launch successfully
- Both backend and Flutter frontend start correctly
- System tray integration works as expected

---

## [1.0.1] - 2025-10-25

### Fixed

#### Critical Bug Fixes
- **Bug #10 (9/10)** - Memory leak: ChatRepositoryImpl.dispose() never called
  - Added dispose() override in AppRoot (_AppRootState)
  - Properly clean up 4 StreamControllers, 2 StreamSubscriptions, and 1 Timer
  - Files: `frontend_flutter/lib/src/presentation/app/app.dart:52-64`

- **Bug #11 (7/10)** - Infinite loop in BackendWsClient.connect()
  - Added maxAttempts = 10 to prevent UI freeze when backend unavailable
  - Emit error status after max attempts reached
  - Files: `frontend_flutter/lib/src/features/chat/data/datasources/backend_ws_client.dart:116-139`

- **Bug #12 (4/10)** - Excessive production logging
  - Wrapped all print() statements in `kDebugMode` checks (8 locations)
  - Improves performance and reduces noise in production builds
  - Files: `frontend_flutter/lib/src/features/chat/data/repositories/chat_repository_impl.dart`

#### Window Transparency Restoration
- **Restored original transparent window configuration** from commit 52f22db (Sept 17, 2025)
  - Re-added 13 lines of macOS window transparency settings in MainFlutterWindow.swift
  - Settings: isOpaque, backgroundColor, titleVisibility, hasShadow, layer configs, etc.
  - These were accidentally deleted in commit a744a4b (Oct 19, 2025)
  - Files: `frontend_flutter/macos/Runner/MainFlutterWindow.swift:11-26`

- **Improved content visibility**
  - Changed alpha from 0.5 to 0.95 for AppBar, panels, and sidebar
  - Background fully transparent (desktop visible through empty areas)
  - Content clearly visible with 95% opacity (great readability)
  - Files:
    - `frontend_flutter/lib/src/features/chat/presentation/screen/chat_screen.dart:41,135`
    - `frontend_flutter/lib/src/features/chat/presentation/widgets/chat_list_sidebar.dart:17`

---

## [1.0.0] - 2025-10-25

### Added

#### Core Features
- 🔐 **Secure API Key Management**
  - Platform-specific secure storage (macOS Keychain, Windows Credential Manager, Linux libsecret)
  - First-run setup dialog for easy onboarding
  - Settings screen for API key configuration
  - Support for both Anthropic and OpenAI API keys
  - API key format validation with helpful error messages

#### User Interface
- 🎨 **Modern Flutter UI**
  - Cross-platform desktop application (macOS, Windows, Linux)
  - Web support with localStorage fallback
  - Real-time connection status indicators
  - Chat-based interface with visual feedback
  - Cost tracking and usage metrics

#### Backend
- 🚀 **Single Binary Launcher**
  - Unified launcher that runs both Python backend and Flutter frontend
  - System tray integration for easy access
  - Automatic reconnection with exponential backoff
  - WebSocket-based communication (JSON-RPC 2.0)
  - Graceful shutdown with cleanup

#### Developer Experience
- ✅ **Comprehensive Testing**
  - Python unit tests for API key management
  - Flutter unit tests for services and data sources
  - CI/CD pipeline with automated testing
  - Integration tests for critical paths

---

### Security Fixes

#### Critical Security Issues (10/10)
1. **API Key Race Condition** - Fixed API keys leaking between concurrent WebSocket connections
   - Changed from instance variable to local variable per connection
   - Files: `packages/backend/src/os_ai_backend/ws.py`

2. **API Key Logging Leak** - Fixed API keys being logged in plaintext to console
   - Now logs only `host:port:path`, query parameters excluded
   - Files: `frontend_flutter/lib/src/features/chat/data/datasources/backend_ws_client.dart`

#### High Priority Security Issues (9/10)
3. **Memory Leak in WebSocket** - Fixed subscription not being cancelled on reconnect
   - Added `_mappedSub` tracking and proper cleanup
   - Files: `frontend_flutter/lib/src/features/chat/data/datasources/backend_ws_client.dart`

---

### Bug Fixes

#### Critical Bugs
4. **Missing API Key UX** (6/10) - Added clear error message when API key is not configured
   - Error: "API key required. Please configure your Anthropic API key in Settings."
   - Files: `packages/backend/src/os_ai_backend/ws.py`

5. **Invalid API Key Handling** (6/10) - Added handling for 401/403 authentication errors
   - Error: "Invalid or expired API key. Please check your Anthropic API key in Settings."
   - Files: `packages/backend/src/os_ai_backend/ws.py`

6. **Backend Crash Detection** (3/10) - Launcher now checks if backend started successfully
   - Added `threading.Event` synchronization
   - Files: `launcher.py`

#### Serious Bugs
7. **Race Condition in close()** (7/10) - Fixed crashes when calling close() multiple times
   - Added `_isClosed` flag and safe `_addStatus()` helper
   - Files: `frontend_flutter/lib/src/features/chat/data/datasources/backend_ws_client.dart`

8. **Launcher UX** (7/10) - Launcher now exits gracefully if services fail to start
   - No longer shows tray icon when backend/frontend failed
   - Files: `launcher.py`

#### Minor Bugs
9. **Silent Exception Swallowing** (5/10) - Added debug logging for exceptions
   - Better debugging for attachment processing and message parsing
   - Files: `packages/backend/src/os_ai_backend/ws.py`

10. **Graceful Shutdown** (6/10) - Added proper cleanup on exit
    - 3-second timeout for backend thread
    - 5-second timeout for Flutter termination
    - Files: `launcher.py`

---

### Changed

- **Flutter App Path Resolution** - Fixed paths for PyInstaller bundles
  - Now correctly looks in `_MEIPASS/flutter_app/` for all platforms
  - Files: `launcher.py`

- **WebSocket Connection Status** - Improved status tracking with safe updates
  - Protected against double-close scenarios
  - Files: `frontend_flutter/lib/src/features/chat/data/datasources/backend_ws_client.dart`

- **CI/CD Pipeline** - Added Flutter testing to CI
  - Flutter analyze + flutter test now run automatically
  - Files: `.github/workflows/ci.yml`

---

### Technical Improvements

- Added `pytest-asyncio` support for async test execution
- Added `asyncio_mode = auto` to pytest configuration
- Improved error messages throughout the application
- Enhanced logging for debugging (without security leaks)
- Updated documentation with all bug fixes

---

### Documentation

- ✅ **Complete User Guide** (`USER_GUIDE.md`)
  - Installation instructions for all platforms
  - How to get API key from Anthropic
  - Troubleshooting section
  - Privacy & security information

- ✅ **Implementation Documentation** (`API_KEY_MANAGEMENT_IMPLEMENTATION.md`)
  - Complete architecture documentation
  - All bug fixes documented
  - Security guarantees explained

- ✅ **Updated README** with end-user section
  - Clear separation between user and developer docs
  - Download links and quick start guide

---

### Known Limitations

1. **Web Platform Security** - Uses localStorage instead of native keychain (less secure)
2. **Single Key per Provider** - Only one Anthropic key and one OpenAI key supported
3. **No Auto-Rotation** - Users must manually update expired keys
4. **No Biometric Auth** - Direct API key access without additional authentication

---

### Breaking Changes

None - This is the first major release.

---

### Migration Guide

#### From CLI-only Usage

If you were using the CLI (`python main.py --task "..."`):
1. The CLI still works with environment variables (`ANTHROPIC_API_KEY`)
2. For GUI, API keys are now stored in system keychain
3. First launch will prompt you to enter API key
4. Old `.env` files still work as fallback

---

### Upgrade Instructions

#### First Time Install
1. Download release for your platform
2. Run the application
3. Enter API key in welcome dialog
4. Start using!

#### Upgrading from Pre-1.0
1. Your `ANTHROPIC_API_KEY` environment variable will continue to work
2. For GUI storage, enter key in Settings screen
3. No data migration needed

---

### Contributors

- Built with Claude Code
- Based on Anthropic's Computer Use reference implementation
- Community feedback and testing

---

### Links

- **Repository**: https://github.com/777genius/os-ai-computer-use
- **Issues**: https://github.com/777genius/os-ai-computer-use/issues
- **Releases**: https://github.com/777genius/os-ai-computer-use/releases
- **User Guide**: [USER_GUIDE.md](USER_GUIDE.md)
- **Documentation**: [API_KEY_MANAGEMENT_IMPLEMENTATION.md](API_KEY_MANAGEMENT_IMPLEMENTATION.md)

---

## [Unreleased]

### Planned Features
- [ ] Test connection button in settings
- [ ] Multiple API key profiles
- [ ] API usage dashboard
- [ ] Key rotation reminders
- [ ] WSS (secure WebSocket) option
- [ ] Biometric authentication for key access
- [ ] Integration tests for full stack
- [ ] Performance monitoring

---

*This changelog follows the [Keep a Changelog](https://keepachangelog.com/) format.*
