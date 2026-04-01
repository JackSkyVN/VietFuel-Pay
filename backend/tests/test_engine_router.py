"""
Integration tests for the Engine endpoints using HTTPX async test client.
"""
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch

from app.main import app


@pytest.mark.asyncio
async def test_ai_trigger_returns_log():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        with patch("app.services.engine_service.handle_ai_trigger") as mock_service:
            from app.schemas.engine import AiTriggerResponse
            import uuid
            mock_service.return_value = AiTriggerResponse(
                log_id=uuid.uuid4(),
                license_plate="51G-123.45",
                confidence_score=0.97,
                message="AI trigger logged. Awaiting IoT data.",
            )

            resp = await client.post(
                "/api/v1/engine/ai-trigger",
                json={
                    "license_plate": "51G-123.45",
                    "confidence_score": 0.97,
                    "station_id": "STN-001",
                    "camera_id": "CAM-A1",
                },
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["license_plate"] == "51G-123.45"
            assert "log_id" in data


@pytest.mark.asyncio
async def test_iot_trigger_returns_transaction():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        with patch("app.services.engine_service.handle_iot_trigger") as mock_service:
            from app.schemas.engine import IoTTriggerResponse
            import uuid
            mock_service.return_value = IoTTriggerResponse(
                transaction_id=uuid.uuid4(),
                status="PENDING",
                message="IoT trigger received. Awaiting AI recognition.",
            )

            resp = await client.post(
                "/api/v1/engine/iot-trigger",
                json={
                    "license_plate": "51G-123.45",
                    "fuel_liters": 20.5,
                    "amount_vnd": 450000.0,
                    "station_id": "STN-001",
                    "pump_id": "PUMP-03",
                },
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "PENDING"
            assert "transaction_id" in data
