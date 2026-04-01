"""
FastAPI dependency injection helpers.
"""
from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_access_token
from app.core.exceptions import UnauthorizedException


async def get_current_customer_id(
    authorization: Annotated[str | None, Header()] = None,
) -> uuid.UUID:
    """
    FastAPI dependency – extracts and validates the customer JWT from the
    Authorization header and returns the customer UUID.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise UnauthorizedException("Missing or malformed Authorization header.")
    token = authorization.split(" ", 1)[1]
    try:
        payload = decode_access_token(token)
        customer_id = uuid.UUID(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise UnauthorizedException("Invalid or expired access token.")
    return customer_id


async def get_current_admin_id(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """
    FastAPI dependency – validates an admin/staff JWT and returns the staff ID.
    Expects the token payload to contain role='admin' or role='staff'.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise UnauthorizedException("Missing or malformed Authorization header.")
    token = authorization.split(" ", 1)[1]
    try:
        payload = decode_access_token(token)
        role = payload.get("role", "")
        if role not in ("admin", "staff"):
            raise UnauthorizedException("Insufficient privileges.")
        return payload["sub"]
    except (JWTError, KeyError):
        raise UnauthorizedException("Invalid or expired access token.")
