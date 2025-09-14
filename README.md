# OS AI Computer Use

[![CI](https://github.com/iliyaZelenko/os-ai-computer-use/actions/workflows/ci.yml/badge.svg)](https://github.com/iliyaZelenko/os-ai-computer-use/actions/workflows/ci.yml)

Local agent for desktop automation. It currently integrates Anthropic Computer Use (Claude) but is architected to be provider‑agnostic: the LLM layer is abstracted behind `LLMClient`, so OpenAI Computer Use (and others) can be added with minimal changes.

What this project is:
- A provider‑agnostic Computer Use agent with a stable tool interface
- An OS‑agnostic execution layer using ports/drivers (macOS and Windows today)
- A CLI you can bundle into a single executable for local use

What it is not (yet):
- A remote SaaS; this is a local agent
- A finished set of drivers for every OS/desktop (Linux Wayland has limits for synthetic input)

Highlights:
- Smooth mouse movement, clicks, drag‑and‑drop with easing and timing controls
- Reliable keyboard input (robust Enter on macOS), hotkeys and hold sequences
- Screenshots (Quartz on macOS or PyAutoGUI fallback), on‑disk saving and base64 tool_result
- Detailed logs and running cost estimation per iteration and total

See provider architecture in `docs/architecture-universal-llm.md`, OS ports/drivers in `docs/os-architecture.md`, and packaging notes in `docs/ci-packaging.md`.

## Installation & Setup

Requirements:
- macOS 13+ or Windows 10/11
- Python 3.12+
- Anthropic API key: `ANTHROPIC_API_KEY` (for now; OpenAI planned)

Install:
```bash
# (optional) create and activate venv
python -m venv .venv && source .venv/bin/activate

# install dependencies
make install

# (optional) install local packages in editable mode (mono-repo dev)
make dev-install
```

macOS permissions (for GUI automation):
```bash
make macos-perms  # opens System Settings → Privacy & Security panels
```
Grant permissions to Terminal/iTerm and your venv Python under: Accessibility, Input Monitoring, Screen Recording.

---

## Quick start

Requirements:
- macOS 13+ or Windows 10/11 (unit tests on any OS; GUI tests macOS/self‑hosted Windows)
- Python 3.12+
- Anthropic API key (`ANTHROPIC_API_KEY`)

Install:
```bash
# (optional) create and activate venv
python -m venv .venv && source .venv/bin/activate

# install top-level dependencies
make install
```

macOS permissions (required for GUI automation):
```bash
# open System Settings → Privacy & Security panels
make macos-perms
```
Grant permissions to Terminal/iTerm and your venv Python under: Accessibility, Input Monitoring, Screen Recording.

Run the agent (CLI):
```bash
export ANTHROPIC_API_KEY=sk-ant-...
python main.py --provider anthropic --debug --task "Open Safari, search for 'macOS automation', scroll, make a screenshot"
```

### CLI Examples

```bash
# 1) Open Chrome, search in Google, take a screenshot
python main.py --provider anthropic --task "Open Chrome, focus the address bar, type google.com, search for 'computer use AI', open first result, scroll down and take a screenshot"

# 2) Copy/paste workflow in a text editor
python main.py --provider anthropic --task "Open TextEdit, create a new document, type 'Hello world!', select all and copy, create another document and paste"

# 3) Window management + hotkeys
python main.py --provider anthropic --task "Open System Settings, search for 'Privacy', navigate to Privacy & Security, disable GEO"

# 4) Precise drag operations
python main.py --provider anthropic --task "In Finder, open Downloads, switch to icon view, drag the first file to Desktop"
```

Useful make targets:
```bash
make install                     # install top-level dependencies
make test                        # unit tests
RUN_CURSOR_TESTS=1 make itest    # GUI integration tests (macOS; requires permissions)
make itest-local-keyboard        # run keyboard harness
make itest-local-click           # run click/drag harness
```

---

## Features

- Smooth mouse motion: easing, distance‑based durations
- Pre‑move highlight (macOS overlay across Spaces/Fullscreen)
- Clicks with modifiers: `modifiers: "cmd+shift"` for click/down/up
- Drag control: `hold_before_ms`, `hold_after_ms`, `steps`, `step_delay`
- Keyboard input: `key`, `hold_key`; robust Enter on macOS via Quartz
- Screenshots: Quartz (macOS) or PyAutoGUI fallback; optional downscale for model display
- Logging and cost: per‑iteration and total usage/cost with 429 retry logic

## Supported Platforms

- OS‑agnostic execution: core depends only on OS ports; drivers are loaded per OS (see `docs/os-architecture.md`).
- macOS (supported):
  - Full driver set with overlay (AppKit), robust Enter (Quartz), screenshots (Quartz/PyAutoGUI), sounds (NSSound).
  - Integration tests available; requires Accessibility, Input Monitoring, Screen Recording.
  - Single‑file CLI bundle via `make build-macos-bundle`.
- Windows (implemented, not yet integration‑tested):
  - Drivers for mouse/keyboard/screen via PyAutoGUI; overlay/sound are no‑ops baseline.
  - Unit contract tests exist; for GUI tests use a self‑hosted Windows runner (see `docs/windows-integration-testing.md`).
  - Single‑file CLI bundle via `make build-windows-bundle` (build on Windows).
- Linux: not provided out‑of‑the‑box. X11 can support synthetic input (XTest), while Wayland often restricts it. Contributions welcome.

---

## Configuration (config/settings.py)

Key options (partial list):
- Coordinates/calibration
  - `COORD_X_SCALE`, `COORD_Y_SCALE`, `COORD_X_OFFSET`, `COORD_Y_OFFSET`
  - Post‑move correction: `POST_MOVE_VERIFY`, `POST_MOVE_TOLERANCE_PX`, `POST_MOVE_CORRECTION_DURATION`
- Screenshots
  - `SCREENSHOT_MODE` (native|downscale)
  - `VIRTUAL_DISPLAY_ENABLED`, `VIRTUAL_DISPLAY_WIDTH_PX`, `VIRTUAL_DISPLAY_HEIGHT_PX`
  - `SCREENSHOT_FORMAT` (PNG|JPEG), `SCREENSHOT_JPEG_QUALITY`
- Overlay
  - `PREMOVE_HIGHLIGHT_ENABLED`, `PREMOVE_HIGHLIGHT_DEFAULT_DURATION`, `PREMOVE_HIGHLIGHT_RADIUS`, colors
- Model/tool
  - `MODEL_NAME`, `COMPUTER_TOOL_TYPE`, `COMPUTER_BETA_FLAG`, `MAX_TOKENS`
  - `ALLOW_PARALLEL_TOOL_USE`

See file for full list and comments.

---

## Tool input (API)

The agent expects blocks with `action` and parameters:

- Mouse movement
```json
{"action":"mouse_move","coordinate":[x,y],"coordinate_space":"auto|screen|model","duration":0.35,"tween":"linear"}
```
- Clicks
```json
{"action":"left_click","coordinate":[x,y],"modifiers":"cmd+shift"}
```
- Key press / hold
```json
{"action":"key","key":"cmd+l"}
{"action":"hold_key","key":"ctrl+shift+t"}
```
- Drag‑and‑drop
```json
{
  "action":"left_click_drag",
  "start":[x1,y1],
  "end":[x2,y2],
  "modifiers":"shift",
  "hold_before_ms":80,
  "hold_after_ms":80,
  "steps":4,
  "step_delay":0.02
}
```
- Scroll
```json
{"action":"scroll","coordinate":[x,y],"scroll_direction":"down|up|left|right","scroll_amount":3}
```
- Typing
```json
{"action":"type","text":"Hello, world!"}
```
- Screenshot
```json
{"action":"screenshot"}
```

Responses are returned as a list of tool_result content blocks (text/image). Screenshots are base64‑encoded.

---

## Tests

Unit tests (no real GUI):
```bash
make test
```
Integration (real OS tests, macOS; Windows via self‑hosted runner):
```bash
export RUN_CURSOR_TESTS=1
make itest
```
If macOS blocks automation, tests are skipped. Grant permissions with `make macos-perms` and retry.

Windows integration testing options are described in `docs/windows-integration-testing.md`.

---

## Flutter integration

Recommended setup: Flutter as pure UI, local Python service:
- Transport: WebSocket + JSON‑RPC for chat/commands, REST for files
- Streams: screenshots (JPEG/PNG), logs, events
- Example notes: `docs/flutter.md`

Note: project code and docs use English.

---

## Contributing

- Fork → feature branch → PR
- Code style: readable, explicit names, avoid deep nesting
- Tests: add unit tests and integration tests when applicable
- Before PR:
```bash
make test
RUN_CURSOR_TESTS=1 make itest   # optional if GUI interactions changed
```
- Commit messages: clear and atomic

Architecture, packaging and testing docs:
- OS Ports & Drivers: `docs/os-architecture.md`
- Packaging & CI: `docs/ci-packaging.md`
- Windows integration testing: `docs/windows-integration-testing.md`
- Code style: `CODE_STYLE.md`
- Contributing: `CONTRIBUTING.md`

Packaging (single executable bundles):
- macOS: `make build-macos-bundle` → `dist/agent_core/agent_core`
- Windows: `make build-windows-bundle` → `dist/agent_core/agent_core.exe`

---

## License

Apache License 2.0. Preserve `NOTICE` when distributing.

- See `LICENSE` and `NOTICE` at repository root.

---

## Troubleshooting

- Cursor/keyboard don’t work (macOS): grant permissions in System Settings → Privacy & Security (Accessibility, Input Monitoring, Screen Recording) for Terminal and current Python.
- Integration tests skipped: restart terminal, ensure same interpreter (`which python`, `python -c 'import sys; print(sys.executable)'`).
- Screenshots empty/missing overlay: enable Screen Recording; check screenshot mode settings.

---

## Contact

Issues/PR in this repository. Attribution is listed in `NOTICE`.
