"""Tests for multi-provider cost estimation."""

from __future__ import annotations

import pytest
from os_ai_core.utils.costs import estimate_cost, get_rates_for_model


def test_anthropic_sonnet4():
    inp, out, total, tier = estimate_cost("claude-sonnet-4-20250514", 1000, 500)
    assert inp == pytest.approx(1000 / 1_000_000 * 3.0)
    assert out == pytest.approx(500 / 1_000_000 * 15.0)


def test_anthropic_sonnet4_long_context():
    inp_rate, out_rate, tier = get_rates_for_model("claude-sonnet-4-20250514", 250_000)
    assert inp_rate == pytest.approx(6.0)
    assert out_rate == pytest.approx(22.5)
    assert "long-context" in tier


def test_openai_gpt54():
    inp, out, total, tier = estimate_cost("gpt-5.4", 1000, 500)
    assert inp == pytest.approx(1000 / 1_000_000 * 2.50)
    assert out == pytest.approx(500 / 1_000_000 * 15.0)


def test_openai_gpt54_long_context():
    inp_rate, out_rate, tier = get_rates_for_model("gpt-5.4", 300_000)
    assert inp_rate == pytest.approx(5.0)
    assert out_rate == pytest.approx(22.5)
    assert "long-context" in tier


def test_openai_o4mini():
    inp, out, total, tier = estimate_cost("o4-mini", 1000, 500)
    assert inp == pytest.approx(1000 / 1_000_000 * 1.10)
    assert out == pytest.approx(500 / 1_000_000 * 4.40)


def test_unknown_model_fallback():
    inp, out, total, tier = estimate_cost("unknown-model-xyz", 1000, 500)
    assert tier == "base"
    assert total > 0
