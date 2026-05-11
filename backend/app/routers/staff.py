"""
Router – Staff POS  (/api/v1/staff)

GET  /staff/shift          – Today's shift summary for the logged-in staff
GET  /staff/shift/txs      – Today's shift transactions (newest first)
POST /staff/shift/txs      – Record a new shift transaction
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models import ShiftTransaction, StaffMember

router = APIRouter(prefix="/staff", tags=["Staff POS"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class ShiftTransactionOut(BaseModel):
    id: str
    staff_id: str
    license_plate: str
    pump_number: int
    amount_vnd: int
    payment_method: str
    created_at: datetime

    class Config:
        from_attributes = True


class ShiftSummaryOut(BaseModel):
    staff_id: str
    full_name: str
    role: str
    shift_label: str
    total_revenue_vnd: int
    transaction_count: int
    transactions: list[ShiftTransactionOut]


class RecordTransactionIn(BaseModel):
    staff_id: str
    license_plate: str
    pump_number: int
    amount_vnd: int
    payment_method: str = "CASH"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _today_start_end():
    now = datetime.now(timezone.utc)
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end   = now.replace(hour=23, minute=59, second=59, microsecond=999999)
    return start, end


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/shift/{staff_id}", response_model=ShiftSummaryOut)
async def get_shift_summary(
    staff_id: str,
    db: AsyncSession = Depends(get_db),
) -> ShiftSummaryOut:
    try:
        uid = uuid.UUID(staff_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid staff_id format.")

    staff_result = await db.execute(select(StaffMember).where(StaffMember.id == uid))
    staff = staff_result.scalar_one_or_none()
    if staff is None:
        raise HTTPException(status_code=404, detail="Staff member not found.")

    start, end = _today_start_end()
    txs_result = await db.execute(
        select(ShiftTransaction)
        .where(
            ShiftTransaction.staff_id == uid,
            ShiftTransaction.created_at >= start,
            ShiftTransaction.created_at <= end,
        )
        .order_by(ShiftTransaction.created_at.desc())
    )
    txs = txs_result.scalars().all()

    total = sum(t.amount_vnd for t in txs)
    shift_hour = datetime.now(timezone.utc).strftime("%H:%M")
    shift_label = f"Ca hiện tại  06:00 – {shift_hour}"

    return ShiftSummaryOut(
        staff_id=str(staff.id),
        full_name=staff.full_name,
        role=staff.role.value.lower(),
        shift_label=shift_label,
        total_revenue_vnd=total,
        transaction_count=len(txs),
        transactions=[
            ShiftTransactionOut(
                id=str(t.id),
                staff_id=str(t.staff_id),
                license_plate=t.license_plate,
                pump_number=t.pump_number,
                amount_vnd=t.amount_vnd,
                payment_method=t.payment_method,
                created_at=t.created_at,
            )
            for t in txs
        ],
    )


@router.post("/shift/txs", response_model=ShiftTransactionOut, status_code=201)
async def record_transaction(
    payload: RecordTransactionIn,
    db: AsyncSession = Depends(get_db),
) -> ShiftTransactionOut:
    try:
        staff_uid = uuid.UUID(payload.staff_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid staff_id format.")

    tx = ShiftTransaction(
        staff_id=staff_uid,
        license_plate=payload.license_plate.upper().strip(),
        pump_number=payload.pump_number,
        amount_vnd=payload.amount_vnd,
        payment_method=payload.payment_method,
    )
    db.add(tx)
    await db.commit()
    await db.refresh(tx)

    return ShiftTransactionOut(
        id=str(tx.id),
        staff_id=str(tx.staff_id),
        license_plate=tx.license_plate,
        pump_number=tx.pump_number,
        amount_vnd=tx.amount_vnd,
        payment_method=tx.payment_method,
        created_at=tx.created_at,
    )
