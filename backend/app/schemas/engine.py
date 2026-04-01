"""
Pydantic schemas for the Payment Engine module.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


# ── AI Camera Trigger ─────────────────────────────────────────────────────────

class AiTriggerRequest(BaseModel):
    license_plate: str = Field(..., examples=["51G-123.45"], description="Scanned license plate string from AI camera")
    confidence_score: float = Field(..., ge=0.0, le=1.0, examples=[0.97])
    station_id: str = Field(..., examples=["STN-001"])
    camera_id: str = Field(..., examples=["CAM-A1"])
    raw_image_url: str | None = Field(None, examples=["https://cdn.smartrefuel.vn/images/abc.jpg"])
    # GPS of the scanning camera – used for geofence pre-check
    camera_lat: float | None = Field(None, examples=[10.7769])
    camera_lon: float | None = Field(None, examples=[106.7009])


class AiTriggerResponse(BaseModel):
    log_id: uuid.UUID
    license_plate: str
    confidence_score: float
    message: str


# ── IoT Gas Pump Trigger ──────────────────────────────────────────────────────

class IoTTriggerRequest(BaseModel):
    license_plate: str = Field(..., examples=["51G-123.45"])
    fuel_liters: float = Field(..., gt=0, examples=[20.5])
    amount_vnd: float = Field(..., gt=0, examples=[450000.0])
    station_id: str = Field(..., examples=["STN-001"])
    pump_id: str = Field(..., examples=["PUMP-03"])


class IoTTriggerResponse(BaseModel):
    transaction_id: uuid.UUID
    status: str
    message: str


# ── Auto-Payment (internal) ───────────────────────────────────────────────────

class GeofenceValidationResult(BaseModel):
    is_valid: bool
    distance_meters: float
    allowed_radius_meters: float


class PaymentGatewayResult(BaseModel):
    success: bool
    gateway_reference: str | None
    gateway_message: str


class AutoPaymentResult(BaseModel):
    transaction_id: uuid.UUID
    license_plate: str
    amount_vnd: float
    fuel_liters: float
    geofence: GeofenceValidationResult
    gateway: PaymentGatewayResult
    final_status: Literal["SUCCESS", "FAILED"]
