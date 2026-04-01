"""
Admin Service – business logic for the admin/staff dashboard module.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from collections import defaultdict

from jose import JWTError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundException, UnauthorizedException
from app.models import (
    AiRecognitionLog,
    Customer,
    LinkedPaymentMethod,
    OfflineQrToken,
    Transaction,
    TransactionStatus,
    PaymentMethod,
    Vehicle,
)
from app.schemas.admin import (
    AiLogEntry,
    AiMonitorResponse,
    DailyRevenue,
    RevenueResponse,
    RevenueStats,
    ScanOfflineQrRequest,
    ScanOfflineQrResponse,
)
from app.utils.payment_gateway import charge as gateway_charge
from app.utils.qr_generator import decode_qr_payload


# ── Offline QR Scanner (Staff) ────────────────────────────────────────────────

async def process_offline_qr_scan(
    payload: ScanOfflineQrRequest,
    db: AsyncSession,
) -> ScanOfflineQrResponse:
    """Validate the QR token and process a manual payment transaction."""

    # 1. Decode and verify QR JWT
    try:
        decoded = decode_qr_payload(payload.qr_data)
    except JWTError as exc:
        raise UnauthorizedException(f"Invalid or expired QR code: {exc}")

    customer_id = uuid.UUID(decoded["sub"])
    token_jti = uuid.UUID(decoded["jti"])

    # 2. Ensure token exists, is not used, and not expired
    token_result = await db.execute(
        select(OfflineQrToken).where(OfflineQrToken.id == token_jti)
    )
    token_record = token_result.scalar_one_or_none()
    if not token_record:
        raise NotFoundException("QR Token")
    if token_record.is_used:
        raise UnauthorizedException("QR token has already been used.")
    if token_record.expires_at < datetime.now(timezone.utc):
        raise UnauthorizedException("QR token has expired.")

    # 3. Find default payment method
    pm_result = await db.execute(
        select(LinkedPaymentMethod)
        .where(
            LinkedPaymentMethod.customer_id == customer_id,
            LinkedPaymentMethod.is_default == True,  # noqa: E712
        )
        .limit(1)
    )
    pm = pm_result.scalar_one_or_none()
    if not pm:
        raise NotFoundException("Default payment method for customer")

    # 4. Create the transaction record
    transaction = Transaction(
        customer_id=customer_id,
        license_plate="OFFLINE-QR",
        fuel_liters=payload.fuel_liters,
        amount_vnd=payload.amount_vnd,
        status=TransactionStatus.PENDING,
        payment_method=PaymentMethod.OFFLINE_QR,
        station_id=payload.station_id,
        pump_id=payload.pump_id,
        geofence_validated=True,  # staff is physically at the station
    )
    db.add(transaction)
    await db.flush()

    # 5. Charge the gateway
    gateway_result = await gateway_charge(
        amount_vnd=payload.amount_vnd,
        gateway_token=pm.gateway_token,
        idempotency_key=str(transaction.id),
    )

    if gateway_result.success:
        transaction.status = TransactionStatus.SUCCESS
        transaction.gateway_reference = gateway_result.gateway_reference
        transaction.completed_at = datetime.now(timezone.utc)
        token_record.is_used = True
    else:
        transaction.status = TransactionStatus.FAILED

    return ScanOfflineQrResponse(
        transaction_id=transaction.id,
        customer_id=customer_id,
        status=transaction.status.value,
        message=gateway_result.gateway_message,
    )


# ── AI Monitor ────────────────────────────────────────────────────────────────

async def get_ai_monitor_logs(
    page: int,
    page_size: int,
    station_id: str | None,
    db: AsyncSession,
) -> AiMonitorResponse:
    stmt = select(AiRecognitionLog)
    count_stmt = select(func.count()).select_from(AiRecognitionLog)

    if station_id:
        stmt = stmt.where(AiRecognitionLog.station_id == station_id)
        count_stmt = count_stmt.where(AiRecognitionLog.station_id == station_id)

    total = (await db.execute(count_stmt)).scalar_one()
    items_result = await db.execute(
        stmt.order_by(AiRecognitionLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    items = items_result.scalars().all()

    avg_confidence = (
        sum(i.confidence_score for i in items) / len(items) if items else 0.0
    )

    return AiMonitorResponse(
        total=total,
        page=page,
        page_size=page_size,
        average_confidence=round(avg_confidence, 4),
        items=[AiLogEntry.model_validate(i) for i in items],
    )


# ── Revenue ───────────────────────────────────────────────────────────────────

async def get_revenue(
    period_start: datetime,
    period_end: datetime,
    station_id: str | None,
    db: AsyncSession,
) -> RevenueResponse:
    stmt = select(Transaction).where(
        Transaction.created_at >= period_start,
        Transaction.created_at <= period_end,
    )
    if station_id:
        stmt = stmt.where(Transaction.station_id == station_id)

    result = await db.execute(stmt)
    transactions = result.scalars().all()

    successful = [t for t in transactions if t.status == TransactionStatus.SUCCESS]
    failed = [t for t in transactions if t.status == TransactionStatus.FAILED]

    total_revenue = sum(t.amount_vnd for t in successful)
    total_liters = sum(t.fuel_liters for t in successful)
    avg_tx = total_revenue / len(successful) if successful else 0.0

    # Daily breakdown
    daily: dict[str, dict] = defaultdict(lambda: {"revenue_vnd": 0.0, "transaction_count": 0})
    for tx in successful:
        day = tx.created_at.strftime("%Y-%m-%d")
        daily[day]["revenue_vnd"] += tx.amount_vnd
        daily[day]["transaction_count"] += 1

    daily_list = [
        DailyRevenue(date=d, revenue_vnd=round(v["revenue_vnd"], 2), transaction_count=v["transaction_count"])
        for d, v in sorted(daily.items())
    ]

    return RevenueResponse(
        period_start=period_start.date().isoformat(),
        period_end=period_end.date().isoformat(),
        station_id=station_id,
        stats=RevenueStats(
            total_transactions=len(transactions),
            successful_transactions=len(successful),
            failed_transactions=len(failed),
            total_revenue_vnd=round(total_revenue, 2),
            total_fuel_liters=round(total_liters, 2),
            average_transaction_vnd=round(avg_tx, 2),
        ),
        daily_breakdown=daily_list,
    )
