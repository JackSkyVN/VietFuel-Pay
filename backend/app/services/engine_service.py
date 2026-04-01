"""
Engine Service – core business logic for the AI + IoT payment pipeline.

Flow:
  1. AI Camera  ──► POST /ai-trigger   → stores AiRecognitionLog
  2. IoT Pump   ──► POST /iot-trigger  → creates PENDING Transaction
  3. Internally ──► auto_payment()     → geofence + gateway → finalise Transaction
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import GeofenceViolationException, NotFoundException, PaymentGatewayException
from app.models import (
    AiRecognitionLog,
    Customer,
    LinkedPaymentMethod,
    Transaction,
    TransactionStatus,
    PaymentMethod,
    Vehicle,
)
from app.schemas.engine import (
    AiTriggerRequest,
    AiTriggerResponse,
    AutoPaymentResult,
    GeofenceValidationResult,
    IoTTriggerRequest,
    IoTTriggerResponse,
)
from app.utils.geofence import validate_geofence
from app.utils.payment_gateway import charge as gateway_charge

settings = get_settings()


# ── AI Trigger ────────────────────────────────────────────────────────────────

async def handle_ai_trigger(
    payload: AiTriggerRequest,
    db: AsyncSession,
) -> AiTriggerResponse:
    """Persist AI recognition log and attempt to kick off auto-payment."""
    log = AiRecognitionLog(
        license_plate=payload.license_plate.upper().strip(),
        confidence_score=payload.confidence_score,
        raw_image_url=payload.raw_image_url,
        station_id=payload.station_id,
        camera_id=payload.camera_id,
    )
    db.add(log)
    await db.flush()  # get the DB-generated id

    # If a PENDING transaction already exists for this plate, trigger auto-payment
    pending_tx = await _find_pending_transaction(payload.license_plate, db)
    if pending_tx:
        log.processed = True
        await _auto_payment(
            transaction=pending_tx,
            camera_lat=payload.camera_lat,
            camera_lon=payload.camera_lon,
            db=db,
        )

    return AiTriggerResponse(
        log_id=log.id,
        license_plate=log.license_plate,
        confidence_score=log.confidence_score,
        message="AI trigger received. Auto-payment initiated." if pending_tx else "AI trigger logged. Awaiting IoT data.",
    )


# ── IoT Trigger ───────────────────────────────────────────────────────────────

async def handle_iot_trigger(
    payload: IoTTriggerRequest,
    db: AsyncSession,
) -> IoTTriggerResponse:
    """Create a PENDING transaction and attempt auto-payment if AI log exists."""
    plate = payload.license_plate.upper().strip()

    # Resolve customer via vehicle plate
    vehicle_result = await db.execute(
        select(Vehicle).where(Vehicle.license_plate == plate)
    )
    vehicle = vehicle_result.scalar_one_or_none()

    transaction = Transaction(
        customer_id=vehicle.customer_id if vehicle else None,
        license_plate=plate,
        fuel_liters=payload.fuel_liters,
        amount_vnd=payload.amount_vnd,
        status=TransactionStatus.PENDING,
        payment_method=PaymentMethod.LINKED_CARD,
        station_id=payload.station_id,
        pump_id=payload.pump_id,
    )
    db.add(transaction)
    await db.flush()

    # Check if AI camera has already scanned this plate
    ai_log = await _find_recent_ai_log(plate, db)
    if ai_log:
        ai_log.processed = True
        await _auto_payment(transaction=transaction, db=db)

    return IoTTriggerResponse(
        transaction_id=transaction.id,
        status=transaction.status.value,
        message="IoT trigger received. Auto-payment initiated." if ai_log else "IoT trigger received. Awaiting AI recognition.",
    )


# ── Auto-Payment (internal) ───────────────────────────────────────────────────

async def _auto_payment(
    transaction: Transaction,
    db: AsyncSession,
    camera_lat: float | None = None,
    camera_lon: float | None = None,
) -> AutoPaymentResult:
    """
    Internal orchestration:
      1. Xác thực vị trí (Geofence validation)
      2. Cổng thanh toán (External Payment Gateway)
      3. Finalise transaction status
    """

    # ── Step 1: Geofence validation ───────────────────────────────────
    lat = camera_lat or settings.STATION_LAT
    lon = camera_lon or settings.STATION_LON
    is_valid, distance = validate_geofence(lat, lon)

    geofence_result = GeofenceValidationResult(
        is_valid=is_valid,
        distance_meters=distance,
        allowed_radius_meters=settings.GEOFENCE_RADIUS_METERS,
    )

    transaction.geofence_validated = is_valid
    if not is_valid:
        transaction.status = TransactionStatus.FAILED
        return AutoPaymentResult(
            transaction_id=transaction.id,
            license_plate=transaction.license_plate,
            amount_vnd=transaction.amount_vnd,
            fuel_liters=transaction.fuel_liters,
            geofence=geofence_result,
            gateway=_failed_gateway("Geofence validation failed"),
            final_status="FAILED",
        )

    # ── Step 2: Resolve payment token ─────────────────────────────────
    gateway_token: str | None = None
    if transaction.customer_id:
        pm_result = await db.execute(
            select(LinkedPaymentMethod)
            .where(
                LinkedPaymentMethod.customer_id == transaction.customer_id,
                LinkedPaymentMethod.is_default == True,  # noqa: E712
            )
            .limit(1)
        )
        pm = pm_result.scalar_one_or_none()
        if pm:
            gateway_token = pm.gateway_token

    if not gateway_token:
        transaction.status = TransactionStatus.FAILED
        return AutoPaymentResult(
            transaction_id=transaction.id,
            license_plate=transaction.license_plate,
            amount_vnd=transaction.amount_vnd,
            fuel_liters=transaction.fuel_liters,
            geofence=geofence_result,
            gateway=_failed_gateway("No linked payment method found for customer"),
            final_status="FAILED",
        )

    # ── Step 3: Charge external payment gateway ───────────────────────
    gateway_result = await gateway_charge(
        amount_vnd=transaction.amount_vnd,
        gateway_token=gateway_token,
        idempotency_key=str(transaction.id),
    )

    if gateway_result.success:
        transaction.status = TransactionStatus.SUCCESS
        transaction.gateway_reference = gateway_result.gateway_reference
        transaction.completed_at = datetime.now(timezone.utc)
    else:
        transaction.status = TransactionStatus.FAILED

    return AutoPaymentResult(
        transaction_id=transaction.id,
        license_plate=transaction.license_plate,
        amount_vnd=transaction.amount_vnd,
        fuel_liters=transaction.fuel_liters,
        geofence=geofence_result,
        gateway=gateway_result,
        final_status="SUCCESS" if gateway_result.success else "FAILED",
    )


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _find_pending_transaction(plate: str, db: AsyncSession) -> Transaction | None:
    result = await db.execute(
        select(Transaction)
        .where(
            Transaction.license_plate == plate.upper().strip(),
            Transaction.status == TransactionStatus.PENDING,
        )
        .order_by(Transaction.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _find_recent_ai_log(plate: str, db: AsyncSession) -> AiRecognitionLog | None:
    result = await db.execute(
        select(AiRecognitionLog)
        .where(
            AiRecognitionLog.license_plate == plate.upper().strip(),
            AiRecognitionLog.processed == False,  # noqa: E712
        )
        .order_by(AiRecognitionLog.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


def _failed_gateway(msg: str):
    from app.schemas.engine import PaymentGatewayResult
    return PaymentGatewayResult(success=False, gateway_reference=None, gateway_message=msg)
