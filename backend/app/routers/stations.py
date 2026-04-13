"""
Router – Gas Stations  (/api/v1/stations)

Public endpoint – no authentication required.
Returns all gas stations from the `gas_stations` table so the Flutter
map screen can display custom markers.
"""
from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models import GasStation
from app.schemas.stations import StationListResponse, StationResponse

router = APIRouter(prefix="/stations", tags=["Stations – Map"])


@router.get(
    "",
    response_model=StationListResponse,
    summary="List all gas stations (Danh sách cây xăng)",
    description=(
        "Returns all active gas stations with their geographic coordinates "
        "so the Flutter client can render them as map markers. "
        "This endpoint is **public** – no authentication token required."
    ),
)
async def list_stations(
    db: AsyncSession = Depends(get_db),
) -> StationListResponse:
    result = await db.execute(select(GasStation).order_by(GasStation.name))
    stations = result.scalars().all()

    count_result = await db.execute(select(func.count()).select_from(GasStation))
    total = count_result.scalar_one()

    return StationListResponse(
        total=total,
        items=[StationResponse.model_validate(s) for s in stations],
    )


# ── Dev seed helper (GET /api/v1/stations/seed) ───────────────────────────────
# Injects realistic Hanoi stations so you can test the map without running
# a separate seed script.  Remove before production.

@router.post(
    "/seed",
    summary="[DEV] Seed sample stations",
    tags=["Stations – Map"],
    status_code=201,
)
async def seed_stations(db: AsyncSession = Depends(get_db)):
    """Idempotently insert 6 demo Hanoi gas stations."""
    import uuid as _uuid

    demo = [
        {
            "id": _uuid.UUID("11111111-0000-0000-0000-000000000001"),
            "name": "Petrolimex Station #1 – Hoàn Kiếm",
            "address": "12 Đinh Tiên Hoàng, Hoàn Kiếm, Hà Nội",
            "latitude": 21.0285,
            "longitude": 105.8542,
            "status": "OPEN",
        },
        {
            "id": _uuid.UUID("11111111-0000-0000-0000-000000000002"),
            "name": "Viettel Station – Đống Đa",
            "address": "45 Nguyễn Lương Bằng, Đống Đa, Hà Nội",
            "latitude": 21.0245,
            "longitude": 105.8412,
            "status": "OPEN",
        },
        {
            "id": _uuid.UUID("11111111-0000-0000-0000-000000000003"),
            "name": "Shell – Cầu Giấy",
            "address": "28 Trần Thái Tông, Cầu Giấy, Hà Nội",
            "latitude": 21.0373,
            "longitude": 105.7934,
            "status": "BUSY",
        },
        {
            "id": _uuid.UUID("11111111-0000-0000-0000-000000000004"),
            "name": "Petrolimex Station #4 – Hai Bà Trưng",
            "address": "88 Bà Triệu, Hai Bà Trưng, Hà Nội",
            "latitude": 21.0220,
            "longitude": 105.8470,
            "status": "OPEN",
        },
        {
            "id": _uuid.UUID("11111111-0000-0000-0000-000000000005"),
            "name": "Viettel Station – Tây Hồ",
            "address": "10 Xuân Diệu, Tây Hồ, Hà Nội",
            "latitude": 21.0650,
            "longitude": 105.8380,
            "status": "OPEN",
        },
        {
            "id": _uuid.UUID("11111111-0000-0000-0000-000000000006"),
            "name": "Shell – Long Biên",
            "address": "5 Nguyễn Văn Cừ, Long Biên, Hà Nội",
            "latitude": 21.0390,
            "longitude": 105.8820,
            "status": "CLOSED",
        },
    ]

    inserted = 0
    for d in demo:
        existing = await db.get(GasStation, d["id"])
        if not existing:
            db.add(GasStation(**d))
            inserted += 1

    await db.commit()
    return {"inserted": inserted, "skipped": len(demo) - inserted}
