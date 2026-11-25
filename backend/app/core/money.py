"""Monetary value schemas and minor-unit arithmetic helpers (never floats)."""

from pydantic import BaseModel, ConfigDict, Field


class Money(BaseModel):
    """Canonical monetary amount represented in minor units (e.g. cents)."""

    model_config = ConfigDict(extra="forbid")

    amount_minor: int = Field(..., description="Amount in minor currency units.")
    currency: str = Field(..., min_length=3, max_length=3, pattern=r"^[A-Z]{3}$")


def apply_basis_points(amount_minor: int, bps: int) -> int:
    """Multiply minor amount by basis points (100 bps = 1%) using integer rounding."""
    return (amount_minor * bps + 5000) // 10000
