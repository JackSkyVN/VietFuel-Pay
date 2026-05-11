"""
app/core/rbac.py
─────────────────
Role-Based Access Control (RBAC) dependency layer.

Usage in a router:
    from app.core.rbac import require_roles, CurrentUser

    @router.get("/something")
    async def endpoint(user: CurrentUser = Depends(require_roles(["manager"]))):
        ...  # user.sub, user.role, user.is_staff are available

Permission matrix
─────────────────
Role            | customer | cashier | supervisor | manager
─────────────────────────────────────────────────────────────
/auth/*         |  public  |  public |   public   |  public
/customer/*     |    ✓     |    ✗    |     ✗      |    ✓
/staff/shift/*  |    ✗     |    ✓   |     ✓      |    ✓
/admin/*        |    ✗     |    ✗    |     ✗      |    ✓
/transactions/* |    ✓     |    ✗    |     ✗      |    ✓
/stations/*     |    ✓     |    ✓   |     ✓      |    ✓
/engine/*       | internal | internal| internal  | internal
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Header
from jose import JWTError

from app.core.exceptions import UnauthorizedException
from app.core.security import decode_access_token

# ── All known roles ───────────────────────────────────────────────────────────

ROLE_CUSTOMER   = "customer"
ROLE_CASHIER    = "cashier"
ROLE_SUPERVISOR = "supervisor"
ROLE_MANAGER    = "manager"

STAFF_ROLES = {ROLE_CASHIER, ROLE_SUPERVISOR, ROLE_MANAGER}
ALL_ROLES   = {ROLE_CUSTOMER} | STAFF_ROLES


# ── Authenticated user context ────────────────────────────────────────────────

@dataclass(frozen=True)
class AuthenticatedUser:
    """Decoded JWT payload attached to every protected request."""
    sub:  uuid.UUID   # user / staff member UUID
    role: str         # one of: customer | cashier | supervisor | manager

    @property
    def is_staff(self) -> bool:
        return self.role in STAFF_ROLES

    @property
    def is_manager(self) -> bool:
        return self.role == ROLE_MANAGER

    @property
    def is_customer(self) -> bool:
        return self.role == ROLE_CUSTOMER


# ── Core token extractor ──────────────────────────────────────────────────────

async def _extract_user(
    authorization: Annotated[str | None, Header()] = None,
) -> AuthenticatedUser:
    """
    Base dependency – decodes the Bearer JWT and returns an AuthenticatedUser.
    Raises 401 if the token is missing, malformed, or expired.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise UnauthorizedException("Missing or malformed Authorization header.")
    token = authorization.removeprefix("Bearer ")
    try:
        payload = decode_access_token(token)
        sub  = uuid.UUID(payload["sub"])
        role = str(payload.get("role", ROLE_CUSTOMER))
        if role not in ALL_ROLES:
            raise UnauthorizedException(f"Unknown role '{role}' in token.")
        return AuthenticatedUser(sub=sub, role=role)
    except (JWTError, KeyError, ValueError) as exc:
        raise UnauthorizedException("Invalid or expired access token.") from exc


# ── Role-guard factory ────────────────────────────────────────────────────────

def require_roles(allowed: list[str]):
    """
    Returns a FastAPI dependency that verifies the caller's role is in
    the `allowed` list.  Raises 401 if unauthenticated, 403 if the role
    is not permitted.

    Example:
        Depends(require_roles(["manager", "supervisor"]))
    """
    allowed_set = set(allowed)

    async def _guard(
        user: Annotated[AuthenticatedUser, Depends(_extract_user)],
    ) -> AuthenticatedUser:
        if user.role not in allowed_set:
            raise UnauthorizedException(
                f"Access denied. Required role(s): {sorted(allowed_set)}. "
                f"Your role: '{user.role}'."
            )
        return user

    return _guard


# ── Pre-built typed guards (import and use directly) ─────────────────────────

# Any authenticated user (customer OR staff)
AnyUser       = Annotated[AuthenticatedUser, Depends(require_roles(list(ALL_ROLES)))]

# Customer-only access
CustomerOnly  = Annotated[AuthenticatedUser, Depends(require_roles([ROLE_CUSTOMER]))]

# Any staff member (cashier / supervisor / manager)
AnyStaff      = Annotated[AuthenticatedUser, Depends(require_roles(list(STAFF_ROLES)))]

# Supervisor or manager
SupervisorUp  = Annotated[AuthenticatedUser, Depends(require_roles([ROLE_SUPERVISOR, ROLE_MANAGER]))]

# Manager only
ManagerOnly   = Annotated[AuthenticatedUser, Depends(require_roles([ROLE_MANAGER]))]

# Customers + managers (e.g. managers can inspect customer data)
CustomerOrManager = Annotated[AuthenticatedUser, Depends(require_roles([ROLE_CUSTOMER, ROLE_MANAGER]))]
