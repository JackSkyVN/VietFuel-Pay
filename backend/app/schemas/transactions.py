"""
Pydantic schemas for the Smart Wallet / Demo Payment flow.
"""
from __future__ import annotations

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


class PendingPaymentInfo(BaseModel):
    """
    Returned by GET /awaiting-payment when a pump has set an amount on a
    PENDING transaction that the customer hasn't confirmed yet.
    Flutter polls this endpoint every 3 seconds.
    """

    transaction_id: str
    license_plate: str
    amount_vnd: int = Field(..., description="Amount set by the pump, in VND.")
    station_id: str | None = None
    pump_id: str | None = None


class SimulatePumpRequest(BaseModel):
    """
    Body for POST /simulate-pump – lets a demo operator (or Postman) act as
    an IoT pump by setting an amount on the PENDING demo transaction.
    """

    amount_vnd: int = Field(
        ...,
        gt=0,
        description="Amount the pump is requesting, in VND.",
        examples=[150000, 300000],
    )
    license_plate: str = Field(
        default="29A-123.45",
        description="License plate detected by ALPR camera.",
    )
    customer_id: str | None = Field(
        default=None,
        description=(
            "Optional: UUID of the logged-in customer. When provided, the demo "
            "transaction is re-linked to this customer so the deduction hits the "
            "correct wallet. If omitted, the hardcoded demo customer is used."
        ),
    )

