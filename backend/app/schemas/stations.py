"""
Pydantic schemas – Gas Stations module.
"""
from __future__ import annotations

import uuid

from pydantic import BaseModel, Field


class StationResponse(BaseModel):
    """Single gas-station record returned by GET /api/v1/stations."""

    id: uuid.UUID
    name: str
    address: str
    latitude: float
    longitude: float
    status: str  # e.g. "OPEN", "CLOSED", "BUSY"

    model_config = {"from_attributes": True}


class StationListResponse(BaseModel):
    total: int
    items: list[StationResponse]
