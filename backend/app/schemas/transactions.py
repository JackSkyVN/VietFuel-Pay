"""
Pydantic schemas for the Smart Wallet / Demo Payment flow.
"""
from __future__ import annotations

import uuid

from pydantic import BaseModel, Field


class DemoPaymentRequest(BaseModel):
    """Body sent by the Flutter app when the customer taps 'Confirm & Pay'."""

    final_amount: int = Field(
        ...,
        gt=0,
        description="Amount to deduct from the customer wallet, in VND (integer).",
        examples=[50000, 100000, 500000],
    )


class PaymentResponse(BaseModel):
    """Response returned after a successful demo payment."""

    status: str = Field(..., examples=["COMPLETED"])
    transaction_id: str = Field(..., examples=["550e8400-e29b-41d4-a716-446655440000"])
    new_balance: int = Field(..., description="Customer's wallet balance after deduction, in VND.")
