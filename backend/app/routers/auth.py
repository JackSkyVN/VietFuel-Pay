"""
Router – Authentication  (/api/v1/auth)

POST /auth/login        – Customer: validate phone + password, return JWT
POST /auth/register     – Customer: create account, return JWT
POST /auth/staff-login  – Staff: validate phone/employee_code + password,
                          return JWT with role field
"""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models import Customer, StaffMember

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
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+=/\\\[\]~`]", v):
            raise ValueError("Password must contain at least one special character.")
        return v


class LoginResponse(BaseModel):
    """Returned for both customer and staff logins."""
    access_token: str
    token_type: str = "bearer"
    customer_id: str          # maps to either customer.id or staff_member.id
    full_name: str
    phone: str
    role: str = "customer"    # "customer" | "cashier" | "supervisor" | "manager"


class StaffLoginRequest(BaseModel):
    """Staff can log in with either their phone OR their employee_code."""
    identifier: str = Field(
        ...,
        examples=["0901111001", "NV001"],
        description="Phone number OR employee code",
    )
    password: str = Field(..., min_length=6, examples=["Staff@1234"])


# ── Customer Login ─────────────────────────────────────────────────────────────

@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Unified Login (Đăng nhập)",
    description=(
        "Authenticates a **customer** or a **staff member** with a single endpoint. "
        "The backend checks the customers table first; if no match is found, it checks "
        "the staff_members table. The response always includes a `role` field "
        "(`customer` | `cashier` | `supervisor` | `manager`) so the client can "
        "route to the correct dashboard without any manual role selection."
    ),
)
async def login(
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    INVALID = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect phone number or password.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # ── 1. Try customer table ─────────────────────────────────────────────────
    cust_result = await db.execute(
        select(Customer).where(Customer.phone == payload.phone)
    )
    customer = cust_result.scalar_one_or_none()

    if customer is not None:
        if not customer.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is disabled. Please contact support.",
            )
        if not verify_password(payload.password, customer.hashed_password):
            raise INVALID
        token = create_access_token(data={"sub": str(customer.id), "role": "customer"})
        return LoginResponse(
            access_token=token,
            customer_id=str(customer.id),
            full_name=customer.full_name,
            phone=customer.phone,
            role="customer",
        )

    # ── 2. Try staff table (phone match) ──────────────────────────────────────
    staff_result = await db.execute(
        select(StaffMember).where(StaffMember.phone == payload.phone)
    )
    staff = staff_result.scalar_one_or_none()

    if staff is not None:
        if not staff.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Staff account is disabled. Contact your manager.",
            )
        if not verify_password(payload.password, staff.hashed_password):
            raise INVALID
        role = staff.role.value.lower()
        token = create_access_token(data={"sub": str(staff.id), "role": role})
        return LoginResponse(
            access_token=token,
            customer_id=str(staff.id),
            full_name=staff.full_name,
            phone=staff.phone,
            role=role,
        )

    # ── 3. Neither found ──────────────────────────────────────────────────────
    raise INVALID


# ── Customer Register ─────────────────────────────────────────────────────────

@router.post(
    "/register",
    response_model=LoginResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Customer Register (Đăng ký)",
)
async def register(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    existing = await db.execute(
        select(Customer).where(Customer.phone == payload.phone)
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This phone number is already registered. Please log in.",
        )

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

    token = create_access_token(data={"sub": str(new_customer.id), "role": "customer"})

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        customer_id=str(new_customer.id),
        full_name=new_customer.full_name,
        phone=new_customer.phone,
        role="customer",
    )


# ── Staff Login ───────────────────────────────────────────────────────────────

@router.post(
    "/staff-login",
    response_model=LoginResponse,
    summary="Staff POS Login (Nhân viên đăng nhập)",
    description=(
        "Authenticates a gas station staff member by **phone number OR employee code** "
        "plus password. Returns a JWT with the staff role embedded so the Flutter app "
        "can route to the StaffDashboardScreen."
    ),
)
async def staff_login(
    payload: StaffLoginRequest,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    # Try phone first, then employee_code
    result = await db.execute(
        select(StaffMember).where(StaffMember.phone == payload.identifier)
    )
    staff = result.scalar_one_or_none()

    if staff is None:
        result2 = await db.execute(
            select(StaffMember).where(StaffMember.employee_code == payload.identifier)
        )
        staff = result2.scalar_one_or_none()

    INVALID = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect identifier or password.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if staff is None:
        raise INVALID
    if not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff account is disabled. Contact your manager.",
        )
    if not verify_password(payload.password, staff.hashed_password):
        raise INVALID

    role = staff.role.value.lower()   # "cashier" | "supervisor" | "manager"
    token = create_access_token(data={"sub": str(staff.id), "role": role})

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        customer_id=str(staff.id),
        full_name=staff.full_name,
        phone=staff.phone,
        role=role,
    )
