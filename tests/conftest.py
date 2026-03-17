import os
import sys


# Ensure project root is on sys.path so local modules resolve if needed
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Add package src paths so os_ai_* modules import without installation
PKG_SRC_DIRS = [
    os.path.join(PROJECT_ROOT, "packages", "core", "src"),
    os.path.join(PROJECT_ROOT, "packages", "cli", "src"),
    os.path.join(PROJECT_ROOT, "packages", "backend", "src"),
    os.path.join(PROJECT_ROOT, "packages", "llm", "src"),
    os.path.join(PROJECT_ROOT, "packages", "llm_anthropic", "src"),
    os.path.join(PROJECT_ROOT, "packages", "llm_openai", "src"),
    os.path.join(PROJECT_ROOT, "packages", "os", "src"),
    os.path.join(PROJECT_ROOT, "packages", "os-macos", "src"),
    os.path.join(PROJECT_ROOT, "packages", "os-linux", "src"),
    os.path.join(PROJECT_ROOT, "packages", "os-windows", "src"),
]
for p in PKG_SRC_DIRS:
    if os.path.isdir(p) and p not in sys.path:
        sys.path.insert(0, p)

# Skip flaky overlay tests by default unless explicitly enabled
os.environ.setdefault("SKIP_OVERLAY_TESTS", "1")


def pytest_collection_modifyitems(session, config, items):
    # Mark integration tests collected under tests/integration as such
    for item in items:
        if "/tests/integration/" in str(getattr(item, "fspath", "")):
            item.add_marker("integration")


