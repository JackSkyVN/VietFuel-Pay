"""
Router – Smart Wallet Demo Payment  (/api/v1/transactions)

Endpoints:
    POST /api/v1/transactions/{transaction_id}/complete_demo
    GET  /api/v1/transactions/awaiting-payment
    POST /api/v1/transactions/simulate-pump

Real-world flow:
    1. ALPR camera detects plate → engine/ai-trigger
    2. Pump dispenses fuel, measures amount → POST /simulate-pump  (IoT)
       This sets amount_vnd on the PENDING transaction in the DB.
    3. Flutter app polls GET /awaiting-payment every 3 s
    4. When amount_vnd > 0 is detected, a payment approval sheet auto-pops up
    5. Customer taps "Confirm" → POST /complete_demo → wallet deducted
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models import Customer, Transaction, TransactionStatus
from app.schemas.transactions import (
    DemoPaymentRequest,
    PaymentResponse,
    PendingPaymentInfo,
    SimulatePumpRequest,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/transactions", tags=["Transactions – Smart Wallet Demo"])


# ── 1. Complete payment (customer confirms) ───────────────────────────────────

@router.post(
    "/{transaction_id}/complete_demo",
    response_model=PaymentResponse,
    status_code=status.HTTP_200_OK,
    summary="Confirm & Pay",
    description=(
        "Called by the Flutter app when the customer taps 'Confirm & Pay'. "
        "Deducts `final_amount` from the wallet and marks the transaction COMPLETED."
    ),
)
async def complete_demo_payment(
    transaction_id: uuid.UUID,
    payload: DemoPaymentRequest,
    db: AsyncSession = Depends(get_db),
) -> PaymentResponse:

    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction: Transaction | None = result.scalar_one_or_none()

    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail=f"Transaction '{transaction_id}' not found.")

    if transaction.status == TransactionStatus.COMPLETED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Transaction has already been paid.")

    if transaction.customer_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Transaction is not linked to any customer account.")

    customer_result = await db.execute(select(Customer).where(Customer.id == transaction.customer_id))
    customer: Customer | None = customer_result.scalar_one_or_none()

    if customer is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Customer account linked to this transaction was not found.")

    if customer.wallet_balance < payload.final_amount:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=(
                f"Insufficient wallet balance. "
                f"Required: {payload.final_amount:,}d — "
                f"Available: {customer.wallet_balance:,}d."
            ),
        )

    try:
        customer.wallet_balance -= payload.final_amount
        transaction.amount_vnd = float(payload.final_amount)
        transaction.status = TransactionStatus.COMPLETED
        transaction.completed_at = datetime.now(timezone.utc)
        await db.flush()
        logger.info("[OK] Payment | txn=%s | amount=%d | new_balance=%d",
                    transaction_id, payload.final_amount, customer.wallet_balance)
    except Exception as exc:
        logger.exception("[ERR] Payment failed | txn=%s | %s", transaction_id, exc)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail="Payment processing failed. Please try again.") from exc

    return PaymentResponse(
        status="COMPLETED",
        transaction_id=str(transaction.id),
        new_balance=customer.wallet_balance,
    )


# ── 2. Poll for awaiting payment (Flutter calls this every 3 s) ───────────────

@router.get(
    "/awaiting-payment",
    response_model=PendingPaymentInfo | None,
    status_code=status.HTTP_200_OK,
    summary="Poll for Pending Payment Request",
    description=(
        "Flutter polls this endpoint every 3 seconds. "
        "Returns a PendingPaymentInfo object when the pump has set an amount "
        "on a PENDING transaction, or null when nothing is waiting."
    ),
)
async def get_awaiting_payment(
    db: AsyncSession = Depends(get_db),
) -> PendingPaymentInfo | None:
    """
    Returns the most recent PENDING transaction where amount_vnd > 0.
    In a production system this would be filtered by the authenticated
    customer's ID via JWT. For the demo it returns any match.
    """
    result = await db.execute(
        select(Transaction)
        .where(
            Transaction.status == TransactionStatus.PENDING,
            Transaction.amount_vnd > 0,
        )
        .order_by(Transaction.created_at.desc())
        .limit(1)
    )
    txn: Transaction | None = result.scalar_one_or_none()

    if txn is None:
        return None

    return PendingPaymentInfo(
        transaction_id=str(txn.id),
        license_plate=txn.license_plate,
        amount_vnd=int(txn.amount_vnd),
        station_id=txn.station_id,
        pump_id=txn.pump_id,
    )


# ── 3. Simulate pump sending an amount (demo / testing) ───────────────────────

@router.post(
    "/simulate-pump",
    status_code=status.HTTP_200_OK,
    summary="Simulate IoT Pump Trigger",
    description=(
        "Demo endpoint that acts as an IoT gas pump. "
        "Resets the demo transaction to PENDING and sets amount_vnd so the "
        "Flutter app's polling detects it and shows the payment approval sheet."
    ),
)
async def simulate_pump(
    payload: SimulatePumpRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """
    Finds the most recent PENDING (or COMPLETED) transaction for the given
    license plate and resets it to PENDING with the requested amount_vnd.
    Creates a new one if none exists.
    """
    result = await db.execute(
        select(Transaction)
        .where(Transaction.license_plate == payload.license_plate)
        .order_by(Transaction.created_at.desc())
        .limit(1)
    )
    txn: Transaction | None = result.scalar_one_or_none()

    if txn is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No transaction found for plate '{payload.license_plate}'. "
                   "Run seed_smart_wallet.py first.",
        )

    # If the caller passes their customer_id, re-link the transaction so
    # complete_demo deducts from the correct (logged-in) customer's wallet.
    if payload.customer_id:
        try:
            txn.customer_id = uuid.UUID(payload.customer_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid customer_id format: '{payload.customer_id}'",
            )

    # Reset to PENDING with the pump's amount
    txn.status = TransactionStatus.PENDING
    txn.amount_vnd = float(payload.amount_vnd)
    txn.completed_at = None
    await db.flush()

    logger.info("[PUMP] Simulated | plate=%s | amount=%d VND | customer=%s | txn=%s",
                payload.license_plate, payload.amount_vnd,
                payload.customer_id or "demo", txn.id)

    return {
        "message": "Pump simulation successful. Flutter app will detect this within 3 seconds.",
        "transaction_id": str(txn.id),
        "license_plate": txn.license_plate,
        "amount_vnd": payload.amount_vnd,
        "customer_id": str(txn.customer_id),
    }


# ── 4. Dismiss pump request (user cancels) ────────────────────────────────────

@router.post(
    "/{transaction_id}/dismiss-pump",
    status_code=status.HTTP_200_OK,
    summary="Dismiss Pump Payment Request",
    description=(
        "Called when the customer taps 'Cancel' on the approval sheet. "
        "Resets amount_vnd to 0 so the polling endpoint stops returning "
        "this transaction and the pop-up does not reappear."
    ),
)
async def dismiss_pump_request(
    transaction_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id)
    )
    txn: Transaction | None = result.scalar_one_or_none()

    if txn is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Transaction '{transaction_id}' not found.",
        )

    # Clear the pump amount — polling will return null on next check
    txn.amount_vnd = 0.0
    await db.flush()

    logger.info("[DISMISS] Pump request dismissed | txn=%s", transaction_id)
    return {"message": "Dismissed", "transaction_id": str(transaction_id)}
