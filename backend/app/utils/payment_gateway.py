"""
Simulated External Payment Gateway client.
In production, replace the httpx call with the real gateway SDK or REST API.
"""
from __future__ import annotations

import uuid
import httpx

from app.core.config import get_settings
from app.schemas.engine import PaymentGatewayResult

settings = get_settings()


async def charge(
    amount_vnd: float,
    gateway_token: str,
    idempotency_key: str | None = None,
) -> PaymentGatewayResult:
    """
    Send a charge request to the external payment gateway.

    Args:
        amount_vnd: Amount to charge in Vietnamese Dong.
        gateway_token: Tokenised card/wallet reference stored per customer.
        idempotency_key: Optional unique key to prevent duplicate charges.

    Returns:
        PaymentGatewayResult with success flag and gateway reference.
    """
    key = idempotency_key or str(uuid.uuid4())
    payload = {
        "amount": int(amount_vnd),
        "currency": "VND",
        "token": gateway_token,
        "idempotency_key": key,
    }
    headers = {
        "Authorization": f"Bearer {settings.PAYMENT_GATEWAY_API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                settings.PAYMENT_GATEWAY_URL,
                json=payload,
                headers=headers,
            )
            resp.raise_for_status()
            data = resp.json()
            return PaymentGatewayResult(
                success=data.get("status") == "approved",
                gateway_reference=data.get("reference_id"),
                gateway_message=data.get("message", "OK"),
            )
    except httpx.HTTPStatusError as exc:
        return PaymentGatewayResult(
            success=False,
            gateway_reference=None,
            gateway_message=f"HTTP {exc.response.status_code}: {exc.response.text}",
        )
    except httpx.RequestError as exc:
        return PaymentGatewayResult(
            success=False,
            gateway_reference=None,
            gateway_message=f"Connection error: {exc}",
        )
