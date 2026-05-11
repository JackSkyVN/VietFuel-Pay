"""
FastAPI dependency injection helpers.

Legacy shims are kept for backward compatibility with existing routers.
New routers should import guards directly from app.core.rbac instead.
"""
from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import Depends

from app.core.rbac import (  # noqa: F401 – re-exported for convenience
    AnyStaff,
    AnyUser,
    AuthenticatedUser,
    CustomerOnly,
    CustomerOrManager,
    ManagerOnly,
    SupervisorUp,
    _extract_user,
    require_roles,
)
from app.core.database import get_db  # noqa: F401 – re-exported


# ── Legacy shims ──────────────────────────────────────────────────────────────
# These keep existing routers (customer.py, admin.py) working without changes
# while the codebase gradually adopts the new RBAC guards.

async def get_current_customer_id(
    user: Annotated[AuthenticatedUser, Depends(require_roles(["customer", "manager"]))],
) -> uuid.UUID:
    """
    Legacy dependency – returns the authenticated customer/manager UUID.
    Migrated routes should switch to CustomerOnly or CustomerOrManager directly.
    """
    return user.sub


async def get_current_admin_id(
    user: Annotated[AuthenticatedUser, Depends(require_roles(["manager", "supervisor"]))],
) -> str:
    """
    Legacy dependency – returns the authenticated admin/supervisor UUID as str.
    Migrated routes should switch to SupervisorUp or ManagerOnly directly.
    """
    return str(user.sub)
