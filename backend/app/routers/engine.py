"""
Router – Core & Payment Engine  (/api/v1/engine)
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.engine import AiTriggerRequest, AiTriggerResponse, IoTTriggerRequest, IoTTriggerResponse
from app.services.engine_service import handle_ai_trigger, handle_iot_trigger

router = APIRouter(prefix="/engine", tags=["Engine – AI & IoT Payment Pipeline"])


@router.post(
    "/ai-trigger",
    response_model=AiTriggerResponse,
    summary="AI Camera Trigger",
    description=(
        "Receives a scanned license plate string from the AI Camera. "
        "Logs the recognition event and triggers auto-payment if an "
        "open IoT transaction already exists for this plate."
    ),
)
async def ai_trigger(
    payload: AiTriggerRequest,
    db: AsyncSession = Depends(get_db),
) -> AiTriggerResponse:
    return await handle_ai_trigger(payload, db)


@router.post(
    "/iot-trigger",
    response_model=IoTTriggerResponse,
    summary="IoT Gas Pump Trigger",
    description=(
        "Receives fuel amount and cost data from the Gas Pump (Trụ bơm xăng). "
        "Creates a PENDING transaction and initiates auto-payment if AI recognition "
        "has already confirmed the vehicle."
    ),
)
async def iot_trigger(
    payload: IoTTriggerRequest,
    db: AsyncSession = Depends(get_db),
) -> IoTTriggerResponse:
    return await handle_iot_trigger(payload, db)
