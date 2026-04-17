"""
Router – Smart Wallet Demo Payment  (/api/v1/transactions)

Endpoint:
    POST /api/v1/transactions/{transaction_id}/complete_demo

Flow:
    1. Look up the Transaction by ID          → 404 if missing
    2. Guard against double-payment           → 400 if already COMPLETED
    3. Look up the linked Customer            → 404 if orphaned
    4. Check wallet balance                   → 402 if insufficient
    5. Atomically deduct balance & complete   → 500 + rollback on DB error
    6. Return PaymentResponse
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
from app.schemas.transactions import DemoPaymentRequest, PaymentResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/transactions", tags=["Transactions – Smart Wallet Demo"])


@router.post(
    "/{transaction_id}/complete_demo",
    response_model=PaymentResponse,
    status_code=status.HTTP_200_OK,
    summary="Complete Demo Payment",
    description=(
        "Finalises a Smart Wallet demo refueling transaction. "
        "Deducts `final_amount` (VND) from the linked customer's wallet balance "
        "and marks the transaction as COMPLETED."
    ),
)
async def complete_demo_payment(
    transaction_id: uuid.UUID,
    payload: DemoPaymentRequest,
    db: AsyncSession = Depends(get_db),
) -> PaymentResponse:

    # ── Step 1: Fetch transaction ─────────────────────────────────────────────
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id)
    )
    transaction: Transaction | None = result.scalar_one_or_none()

    if transaction is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Transaction '{transaction_id}' not found.",
        )

    # ── Step 2: Guard double-payment ──────────────────────────────────────────
    if transaction.status == TransactionStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction has already been paid.",
        )

    # ── Step 3: Fetch linked customer ─────────────────────────────────────────
    if transaction.customer_id is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction is not linked to any customer account.",
        )

    customer_result = await db.execute(
        select(Customer).where(Customer.id == transaction.customer_id)
    )
    customer: Customer | None = customer_result.scalar_one_or_none()

    if customer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer account linked to this transaction was not found.",
        )

    # ── Step 4: Balance check (HTTP 402 Payment Required) ────────────────────
    if customer.wallet_balance < payload.final_amount:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=(
                f"Insufficient wallet balance. "
                f"Required: {payload.final_amount:,}₫ — "
                f"Available: {customer.wallet_balance:,}₫."
            ),
        )

    # ── Step 5: Atomic update ─────────────────────────────────────────────────
    try:
        customer.wallet_balance -= payload.final_amount
        transaction.amount_vnd = float(payload.final_amount)
        transaction.status = TransactionStatus.COMPLETED
        transaction.completed_at = datetime.now(timezone.utc)

        # flush() sends SQL to DB within the open transaction so we can
        # catch constraint errors here. get_db will commit on clean return
        # or rollback if an exception propagates out of this function.
        await db.flush()

        logger.info(
            "[OK] Demo payment | txn=%s | customer=%s | amount=%d VND | new_balance=%d VND",
            transaction_id,
            customer.id,
            payload.final_amount,
            customer.wallet_balance,
        )

    except Exception as exc:
        logger.exception("[ERR] Demo payment failed | txn=%s | %s", transaction_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Payment processing failed due to a database error. Please try again.",
        ) from exc

    # ── Step 6: Return response ───────────────────────────────────────────────
    return PaymentResponse(
        status="COMPLETED",
        transaction_id=str(transaction.id),
        new_balance=customer.wallet_balance,
    )

