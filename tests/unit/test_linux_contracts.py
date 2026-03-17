import platform
import pytest


@pytest.mark.skipif(platform.system().lower() != "linux", reason="Linux-only contracts")
def test_linux_drivers_loaded():
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    assert hasattr(drv.mouse, "move_to")
    assert hasattr(drv.keyboard, "press_enter")
    sz = drv.screen.size()
    assert sz.width > 0 and sz.height > 0
    assert drv.capabilities.supports_synthetic_input is True
