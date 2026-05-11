"""
Router – Staff POS  (/api/v1/staff)

GET  /staff/shift/{staff_id}  – Today's shift summary (own data only for
                                cashiers, any staff_id for supervisors/managers)
POST /staff/shift/txs         – Record a new shift transaction (cashier+)

RBAC:
  GET  shift/{staff_id}  →  AnyStaff   (but cashiers are locked to their own id)
  POST shift/txs         →  AnyStaff
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.rbac import (
    AnyStaff,
    AuthenticatedUser,
    ROLE_CASHIER,
    require_roles,
)
from app.models import ShiftTransaction, StaffMember

router = APIRouter(prefix="/staff", tags=["Staff POS"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class ShiftTransactionOut(BaseModel):
    id: str
    staff_id: str
    staff_name: str          # cashier's name – useful when supervisor sees all staff
    license_plate: str
    pump_number: int
    amount_vnd: int
    payment_method: str
    created_at: datetime

    class Config:
        from_attributes = True


class ShiftSummaryOut(BaseModel):
    staff_id: str
    full_name: str           # own name for cashier; "Tất cả nhân viên" for supervisor/manager
    role: str
    shift_label: str
    total_revenue_vnd: int
    transaction_count: int
    is_aggregate: bool       # True when the data spans multiple staff members
    transactions: list[ShiftTransactionOut]


class RecordTransactionIn(BaseModel):
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

@router.get(
    "/shift/{staff_id}",
    response_model=ShiftSummaryOut,
    summary="Today's Shift Summary",
    description=(
        "Returns the shift summary and transaction list for a staff member. "
        "**Cashiers** can only fetch their own shift (enforced server-side). "
        "**Supervisors and managers** can query any staff member's shift."
    ),
)
async def get_shift_summary(
    staff_id: str,
    user: AnyStaff,
    db: AsyncSession = Depends(get_db),
) -> ShiftSummaryOut:
    try:
        requested_uid = uuid.UUID(staff_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid staff_id format.")

    # Cashiers can only see their own shift
    if user.role == ROLE_CASHIER and user.sub != requested_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cashiers can only view their own shift data.",
        )

    shift_hour = datetime.now(timezone.utc).strftime("%H:%M")
    start, end = _today_start_end()

    # ── Supervisor / Manager: return ALL staff transactions ───────────────────
    if user.role in ("supervisor", "manager"):
        # Fetch all active staff members with their names for annotation
        staff_result = await db.execute(
            select(StaffMember).where(StaffMember.is_active == True)  # noqa: E712
        )
        all_staff = {s.id: s.full_name for s in staff_result.scalars().all()}

        txs_result = await db.execute(
            select(ShiftTransaction)
            .where(
                ShiftTransaction.created_at >= start,
                ShiftTransaction.created_at <= end,
            )
            .order_by(ShiftTransaction.created_at.desc())
        )
        txs = txs_result.scalars().all()
        total = sum(t.amount_vnd for t in txs)

        return ShiftSummaryOut(
            staff_id=str(user.sub),
            full_name="Tất cả nhân viên",
            role=user.role,
            shift_label=f"Tổng hợp  06:00 – {shift_hour}",
            total_revenue_vnd=total,
            transaction_count=len(txs),
            is_aggregate=True,
            transactions=[
                ShiftTransactionOut(
                    id=str(t.id),
                    staff_id=str(t.staff_id),
                    staff_name=all_staff.get(t.staff_id, "?"),
                    license_plate=t.license_plate,
                    pump_number=t.pump_number,
                    amount_vnd=t.amount_vnd,
                    payment_method=t.payment_method,
                    created_at=t.created_at,
                )
                for t in txs
            ],
        )

    # ── Cashier: own transactions only ────────────────────────────────────────
    staff_result = await db.execute(select(StaffMember).where(StaffMember.id == requested_uid))
    staff = staff_result.scalar_one_or_none()
    if staff is None:
        raise HTTPException(status_code=404, detail="Staff member not found.")

    txs_result = await db.execute(
        select(ShiftTransaction)
        .where(
            ShiftTransaction.staff_id == requested_uid,
            ShiftTransaction.created_at >= start,
            ShiftTransaction.created_at <= end,
        )
        .order_by(ShiftTransaction.created_at.desc())
    )
    txs = txs_result.scalars().all()
    total = sum(t.amount_vnd for t in txs)

    return ShiftSummaryOut(
        staff_id=str(staff.id),
        full_name=staff.full_name,
        role=staff.role.value.lower(),
        shift_label=f"Ca hiện tại  06:00 – {shift_hour}",
        total_revenue_vnd=total,
        transaction_count=len(txs),
        is_aggregate=False,
        transactions=[
            ShiftTransactionOut(
                id=str(t.id),
                staff_id=str(t.staff_id),
                staff_name=staff.full_name,
                license_plate=t.license_plate,
                pump_number=t.pump_number,
                amount_vnd=t.amount_vnd,
                payment_method=t.payment_method,
                created_at=t.created_at,
            )
            for t in txs
        ],
    )


@router.post(
    "/shift/txs",
    response_model=ShiftTransactionOut,
    status_code=201,
    summary="Record Shift Transaction",
    description=(
        "Records a new fuel-dispensing transaction for the authenticated staff member. "
        "The `staff_id` is taken from the JWT — not from the request body — "
        "so a cashier can never record under another staff member's account."
    ),
)
async def record_transaction(
    payload: RecordTransactionIn,
    user: AnyStaff,          # staff_id comes from the verified JWT, not the body
    db: AsyncSession = Depends(get_db),
) -> ShiftTransactionOut:
    tx = ShiftTransaction(
        staff_id=user.sub,   # always the authenticated user's own ID
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


@router.get(
    "/all-shifts",
    response_model=list[ShiftSummaryOut],
    summary="All Staff Shifts Today (Supervisor/Manager only)",
    description="Returns today's shift summaries for every active staff member at the station.",
)
async def get_all_shifts(
    user: Annotated[AuthenticatedUser, Depends(require_roles(["supervisor", "manager"]))],
    db: AsyncSession = Depends(get_db),
) -> list[ShiftSummaryOut]:
    staff_result = await db.execute(
        select(StaffMember).where(StaffMember.is_active == True)  # noqa: E712
    )
    all_staff = staff_result.scalars().all()

    start, end = _today_start_end()
    summaries: list[ShiftSummaryOut] = []

    for staff in all_staff:
        txs_result = await db.execute(
            select(ShiftTransaction)
            .where(
                ShiftTransaction.staff_id == staff.id,
                ShiftTransaction.created_at >= start,
                ShiftTransaction.created_at <= end,
            )
            .order_by(ShiftTransaction.created_at.desc())
        )
        txs = txs_result.scalars().all()
        total = sum(t.amount_vnd for t in txs)
        shift_hour = datetime.now(timezone.utc).strftime("%H:%M")

        summaries.append(ShiftSummaryOut(
            staff_id=str(staff.id),
            full_name=staff.full_name,
            role=staff.role.value.lower(),
            shift_label=f"Ca hiện tại  06:00 – {shift_hour}",
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
        ))

    return summaries
