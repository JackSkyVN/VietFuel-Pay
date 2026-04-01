"""
Customer Service – business logic for the mobile customer module.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import DuplicateEntryException, NotFoundException
from app.models import (
    LinkedPaymentMethod,
    OfflineQrToken,
    Transaction,
    Vehicle,
)
from app.schemas.customer import (
    OfflineQrResponse,
    PaymentMethodCreate,
    PaymentMethodResponse,
    TransactionHistoryResponse,
    TransactionSummary,
    VehicleCreate,
    VehicleResponse,
)
from app.utils.qr_generator import generate_offline_qr


# ── Vehicles ──────────────────────────────────────────────────────────────────

async def add_vehicle(
    customer_id: uuid.UUID,
    payload: VehicleCreate,
    db: AsyncSession,
) -> VehicleResponse:
    # Check for duplicate plate
    existing = await db.execute(
        select(Vehicle).where(Vehicle.license_plate == payload.license_plate.upper().strip())
    )
    if existing.scalar_one_or_none():
        raise DuplicateEntryException("License plate")

    vehicle = Vehicle(
        customer_id=customer_id,
        license_plate=payload.license_plate.upper().strip(),
        make=payload.make,
        model=payload.model,
        is_primary=payload.is_primary,
    )
    db.add(vehicle)
    await db.flush()
    return VehicleResponse.model_validate(vehicle)


# ── Payment Methods ───────────────────────────────────────────────────────────

async def link_payment_method(
    customer_id: uuid.UUID,
    payload: PaymentMethodCreate,
    db: AsyncSession,
) -> PaymentMethodResponse:
    pm = LinkedPaymentMethod(
        customer_id=customer_id,
        provider=payload.provider,
        masked_account=payload.masked_account,
        gateway_token=payload.gateway_token,
        is_default=payload.is_default,
    )
    db.add(pm)
    await db.flush()
    return PaymentMethodResponse.model_validate(pm)


# ── Transaction History ───────────────────────────────────────────────────────

async def get_transaction_history(
    customer_id: uuid.UUID,
    page: int,
    page_size: int,
    db: AsyncSession,
) -> TransactionHistoryResponse:
    offset = (page - 1) * page_size

    total_result = await db.execute(
        select(func.count()).select_from(Transaction).where(Transaction.customer_id == customer_id)
    )
    total = total_result.scalar_one()

    items_result = await db.execute(
        select(Transaction)
        .where(Transaction.customer_id == customer_id)
        .order_by(Transaction.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    items = [TransactionSummary.model_validate(tx) for tx in items_result.scalars().all()]

    return TransactionHistoryResponse(total=total, page=page, page_size=page_size, items=items)


# ── Offline QR ────────────────────────────────────────────────────────────────

async def create_offline_qr(
    customer_id: uuid.UUID,
    db: AsyncSession,
) -> OfflineQrResponse:
    signed_payload, token_id, expires_at, img_b64 = generate_offline_qr(customer_id)

    token_record = OfflineQrToken(
        id=token_id,
        customer_id=customer_id,
        token=signed_payload,
        expires_at=expires_at,
    )
    db.add(token_record)
    await db.flush()

    return OfflineQrResponse(
        token_id=token_id,
        qr_data=signed_payload,
        expires_at=expires_at,
        qr_image_base64=img_b64,
    )
