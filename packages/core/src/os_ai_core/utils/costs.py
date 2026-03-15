from typing import Optional, Tuple

from os_ai_core.config import (
    COST_INPUT_PER_MTOKENS_USD,
    COST_OUTPUT_PER_MTOKENS_USD,
    LONG_CONTEXT_INPUT_TOKENS_THRESHOLD,
    COST_INPUT_PER_MTOKENS_USD_LONG_CONTEXT,
    COST_OUTPUT_PER_MTOKENS_USD_LONG_CONTEXT,
)


def _is_sonnet4_model(model: str) -> bool:
    try:
        m = (model or "").lower().strip()
        return "sonnet" in m and "4" in m
    except Exception:
        return False


def _match_model_pricing(model: str) -> Optional[Tuple[float, float]]:
    """Match model name to pricing. Returns (input_rate_per_mtoken, output_rate_per_mtoken)."""
    m = (model or "").lower().strip()
    if "sonnet" in m and "4" in m:
        return (3.0, 15.0)
    if "opus" in m and "4" in m:
        return (15.0, 75.0)
    if "haiku" in m:
        return (0.80, 4.0)
    if "gpt-5.4" in m:
        return (2.50, 15.0)
    if "gpt-5.2" in m:
        return (2.50, 10.0)
    if "o4-mini" in m:
        return (1.10, 4.40)
    return None


def get_rates_for_model(model: str, input_tokens: int = 0) -> Tuple[float, float, str]:
    """Returns (input_rate, output_rate, tier_label) per 1M tokens."""
    matched = _match_model_pricing(model)
    if matched:
        inp_rate, out_rate = matched
        # Anthropic Sonnet 4 long-context (>=200K)
        if _is_sonnet4_model(model) and int(input_tokens) >= int(LONG_CONTEXT_INPUT_TOKENS_THRESHOLD):
            return (
                float(COST_INPUT_PER_MTOKENS_USD_LONG_CONTEXT),
                float(COST_OUTPUT_PER_MTOKENS_USD_LONG_CONTEXT),
                f"{model}-long-context",
            )
        # OpenAI GPT-5.4 long-context (>=272K)
        if "gpt-5.4" in (model or "").lower() and int(input_tokens) >= 272_000:
            return (inp_rate * 2, out_rate * 1.5, f"{model}-long-context")
        return (inp_rate, out_rate, model)
    # Fallback to config-based rates
    return (
        float(COST_INPUT_PER_MTOKENS_USD),
        float(COST_OUTPUT_PER_MTOKENS_USD),
        "base",
    )


def estimate_cost(model: str, input_tokens: int, output_tokens: int) -> Tuple[float, float, float, str]:
    """Estimate API cost in USD. Returns (input_cost, output_cost, total_cost, pricing_tier)."""
    in_rate, out_rate, tier = get_rates_for_model(model, input_tokens)
    input_cost = (float(input_tokens) / 1_000_000.0) * in_rate
    output_cost = (float(output_tokens) / 1_000_000.0) * out_rate
    return input_cost, output_cost, (input_cost + output_cost), tier
