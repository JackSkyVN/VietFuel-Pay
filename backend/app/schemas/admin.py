"""
Pydantic schemas for the Admin / Staff module.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


# ── Offline QR scan (staff) ───────────────────────────────────────────────────

class ScanOfflineQrRequest(BaseModel):
    qr_data: str = Field(..., description="Raw QR payload scanned by staff device")
    fuel_liters: float = Field(..., gt=0, examples=[15.0])
    amount_vnd: float = Field(..., gt=0, examples=[330000.0])
    station_id: str = Field(..., examples=["STN-001"])
    pump_id: str = Field(..., examples=["PUMP-02"])
    staff_id: str = Field(..., examples=["STAFF-007"])


class ScanOfflineQrResponse(BaseModel):
    transaction_id: uuid.UUID
    customer_id: uuid.UUID
    status: str
    message: str


# ── AI Monitor ────────────────────────────────────────────────────────────────

class AiLogEntry(BaseModel):
    id: uuid.UUID
    license_plate: str
    confidence_score: float
    camera_id: str | None
    station_id: str | None
    processed: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class AiMonitorResponse(BaseModel):
    total: int
    page: int
    page_size: int
    average_confidence: float
    items: list[AiLogEntry]


# ── Revenue ───────────────────────────────────────────────────────────────────

class RevenueStats(BaseModel):
    total_transactions: int
    successful_transactions: int
    failed_transactions: int
    total_revenue_vnd: float
    total_fuel_liters: float
    average_transaction_vnd: float


class DailyRevenue(BaseModel):
    date: str   # ISO date string e.g. "2025-04-01"
    revenue_vnd: float
    transaction_count: int


class RevenueResponse(BaseModel):
    period_start: str
    period_end: str
    station_id: str | None
    stats: RevenueStats
    daily_breakdown: list[DailyRevenue]
