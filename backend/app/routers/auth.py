"""
Router – Authentication  (/api/v1/auth)

POST /auth/login     – validate phone + password, return JWT access token
POST /auth/register  – create new account, return JWT access token
"""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models import Customer

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Vietnam mobile phone regex: starts with 0, total 10 digits
_VN_PHONE_RE = re.compile(r"^0[3|5|7|8|9][0-9]{8}$")


# ── Schemas ───────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    phone: str = Field(..., examples=["0901234567"], description="Customer phone number")
    password: str = Field(..., min_length=6, examples=["Demo@1234"])


class RegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=120, examples=["Nguyen Van A"])
    phone: str = Field(..., examples=["0901234567"], description="Vietnamese mobile number (10 digits, starts with 0)")
    password: str = Field(..., min_length=8, examples=["Secure@123"])
    email: str | None = Field(None, examples=["user@example.com"])

    @field_validator("phone")
    @classmethod
    def validate_vn_phone(cls, v: str) -> str:
        v = v.strip()
        if not _VN_PHONE_RE.match(v):
            raise ValueError(
                "Phone must be a valid Vietnamese mobile number "
                "(10 digits, starts with 03/05/07/08/09)."
            )
        return v

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter.")
        if not re.search(r"[0-9]", v):
            raise ValueError("Password must contain at least one number.")
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+=/\\[\]~`]", v):
            raise ValueError("Password must contain at least one special character.")
        return v


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    customer_id: str
    full_name: str
    phone: str


# ── Login ─────────────────────────────────────────────────────────────────────

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


# ── Register ──────────────────────────────────────────────────────────────────

@router.post(
    "/register",
    response_model=LoginResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Customer Register (Đăng ký)",
    description=(
        "Creates a new customer account with a bcrypt-hashed password. "
        "Returns a JWT access token on success so the client can auto-login. "
        "Returns **409 Conflict** if the phone number is already registered."
    ),
)
async def register(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    # 1. Check for duplicate phone
    existing = await db.execute(
        select(Customer).where(Customer.phone == payload.phone)
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This phone number is already registered. Please log in.",
        )

    # 2. Create customer with hashed password
    new_customer = Customer(
        full_name=payload.full_name.strip(),
        phone=payload.phone,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        is_active=True,
    )
    db.add(new_customer)
    await db.commit()
    await db.refresh(new_customer)

    # 3. Issue JWT (auto-login after registration)
    token = create_access_token(data={"sub": str(new_customer.id)})

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        customer_id=str(new_customer.id),
        full_name=new_customer.full_name,
        phone=new_customer.phone,
    )



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
