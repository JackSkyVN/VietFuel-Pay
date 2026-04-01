"""
Router – Admin Dashboard & Staff  (/api/v1/admin)
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies import get_current_admin_id
from app.schemas.admin import (
    AiMonitorResponse,
    RevenueResponse,
    ScanOfflineQrRequest,
    ScanOfflineQrResponse,
)
from app.services.admin_service import (
    get_ai_monitor_logs,
    get_revenue,
    process_offline_qr_scan,
)

router = APIRouter(prefix="/admin", tags=["Admin – Dashboard & Staff"])


@router.post(
    "/scan-offline-qr",
    response_model=ScanOfflineQrResponse,
    summary="Scan & Process Offline QR (Quét QR Offline)",
    description=(
        "Staff endpoint: validates the customer's offline QR code and "
        "processes a manual payment transaction through the payment gateway. "
        "Each QR token is single-use and time-limited."
    ),
)
async def scan_offline_qr(
    payload: ScanOfflineQrRequest,
    admin_id: Annotated[str, Depends(get_current_admin_id)],
    db: AsyncSession = Depends(get_db),
) -> ScanOfflineQrResponse:
    return await process_offline_qr_scan(payload, db)


@router.get(
    "/monitor-ai",
    response_model=AiMonitorResponse,
    summary="Monitor AI Recognition (Giám sát nhận diện)",
    description=(
        "Fetches paginated AI camera recognition logs including license plates "
        "detected, confidence scores, camera IDs, and processing status. "
        "Supports filtering by station ID."
    ),
)
async def monitor_ai(
    admin_id: Annotated[str, Depends(get_current_admin_id)],
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    station_id: str | None = Query(None, description="Filter by station ID"),
    db: AsyncSession = Depends(get_db),
) -> AiMonitorResponse:
    return await get_ai_monitor_logs(page, page_size, station_id, db)


@router.get(
    "/revenue",
    response_model=RevenueResponse,
    summary="Revenue & Statistics (Quản lý doanh thu)",
    description=(
        "Returns aggregated revenue statistics and a daily breakdown "
        "for a given period. Supports filtering by station ID."
    ),
)
async def revenue(
    admin_id: Annotated[str, Depends(get_current_admin_id)],
    period_start: datetime = Query(
        default_factory=lambda: datetime.now(timezone.utc).replace(day=1, hour=0, minute=0, second=0),
        description="Start of reporting period (ISO 8601 datetime)",
    ),
    period_end: datetime = Query(
        default_factory=lambda: datetime.now(timezone.utc),
        description="End of reporting period (ISO 8601 datetime)",
    ),
    station_id: str | None = Query(None, description="Filter by station ID"),
    db: AsyncSession = Depends(get_db),
) -> RevenueResponse:
    return await get_revenue(period_start, period_end, station_id, db)
