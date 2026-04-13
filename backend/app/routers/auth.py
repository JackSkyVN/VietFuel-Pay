"""
Router – Authentication  (/api/v1/auth)

POST /auth/login   – validate phone + password, return JWT access token
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import create_access_token, verify_password
from app.models import Customer

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    phone: str = Field(..., examples=["0901234567"], description="Customer phone number")
    password: str = Field(..., min_length=6, examples=["Demo@1234"])


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    customer_id: str
    full_name: str
    phone: str


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Customer Login (Đăng nhập)",
    description=(
        "Authenticates a customer by phone number and password. "
        "Returns a JWT access token on success. "
        "Returns **401 Unauthorized** if the phone or password is incorrect."
    ),
)
async def login(
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    # 1. Look up customer by phone
    result = await db.execute(
        select(Customer).where(Customer.phone == payload.phone)
    )
    customer = result.scalar_one_or_none()

    # 2. Verify existence and password – use the same error for both
    #    to avoid leaking whether the phone exists (security best-practice).
    INVALID = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect phone number or password.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if customer is None:
        raise INVALID
    if not customer.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled. Please contact support.",
        )
    if not verify_password(payload.password, customer.hashed_password):
        raise INVALID

    # 3. Issue JWT
    token = create_access_token(data={"sub": str(customer.id)})

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        customer_id=str(customer.id),
        full_name=customer.full_name,
        phone=customer.phone,
    )
