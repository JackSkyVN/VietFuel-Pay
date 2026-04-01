"""
Pydantic schemas for the Customer mobile module.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


# ── Vehicle management ────────────────────────────────────────────────────────

class VehicleCreate(BaseModel):
    license_plate: str = Field(..., examples=["51G-123.45"])
    make: str | None = Field(None, examples=["Honda"])
    model: str | None = Field(None, examples=["Wave Alpha"])
    is_primary: bool = False


class VehicleResponse(BaseModel):
    id: uuid.UUID
    license_plate: str
    make: str | None
    model: str | None
    is_primary: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Payment method management ─────────────────────────────────────────────────

class PaymentMethodCreate(BaseModel):
    provider: str = Field(..., examples=["VISA"])
    masked_account: str = Field(..., examples=["**** **** **** 4242"])
    gateway_token: str = Field(..., examples=["tok_sandbox_abc123"])
    is_default: bool = False


class PaymentMethodResponse(BaseModel):
    id: uuid.UUID
    provider: str
    masked_account: str
    is_default: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Transaction history ───────────────────────────────────────────────────────

class TransactionSummary(BaseModel):
    id: uuid.UUID
    license_plate: str
    fuel_liters: float
    amount_vnd: float
    status: str
    payment_method: str
    station_id: str | None
    pump_id: str | None
    created_at: datetime
    completed_at: datetime | None

    # ── Display helpers for the Flutter UI ──────────────────────────────
    @property
    def station_name(self) -> str:
        """Human-readable station label derived from station_id."""
        _MAP = {
            "STN-001": "Viettel Station — Q.1",
            "STN-002": "Shell Cộng Hòa",
            "STN-003": "Viettel Station — Q.7",
        }
        return _MAP.get(self.station_id or "", self.station_id or "Unknown Station")

    model_config = {"from_attributes": True}


class TransactionHistoryResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[TransactionSummary]


# ── Offline QR ────────────────────────────────────────────────────────────────

class OfflineQrResponse(BaseModel):
    token_id: uuid.UUID
    qr_data: str          # JWT or signed payload to embed in QR image
    expires_at: datetime
    qr_image_base64: str  # Base64-encoded PNG QR image
