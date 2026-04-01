"""
QR Code generation helper – produces a signed JWT payload and a Base64 PNG image.
"""
from __future__ import annotations

import base64
import io
import uuid
from datetime import datetime, timedelta, timezone

import qrcode
from jose import jwt

from app.core.config import get_settings

settings = get_settings()


def _build_qr_payload(customer_id: uuid.UUID, token_id: uuid.UUID, expires_at: datetime) -> str:
    """Create a signed JWT to embed inside the QR code."""
    payload = {
        "sub": str(customer_id),
        "jti": str(token_id),
        "type": "OFFLINE_QR",
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def generate_offline_qr(customer_id: uuid.UUID) -> tuple[str, uuid.UUID, datetime, str]:
    """
    Generate an offline QR for a customer.

    Returns:
        (signed_jwt_payload, token_id, expires_at, base64_png_image)
    """
    token_id = uuid.uuid4()
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=settings.QR_EXPIRY_SECONDS)

    signed_payload = _build_qr_payload(customer_id, token_id, expires_at)

    # ── Render QR image ───────────────────────────────────────────────
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=8,
        border=2,
    )
    qr.add_data(signed_payload)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    img_b64 = base64.b64encode(buffer.getvalue()).decode()

    return signed_payload, token_id, expires_at, img_b64


def decode_qr_payload(qr_data: str) -> dict:
    """Decode and verify a QR JWT. Raises JWTError on invalid token."""
    return jwt.decode(qr_data, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
