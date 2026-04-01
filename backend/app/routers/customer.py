"""
Router – Mobile Customer  (/api/v1/customer)
"""
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies import get_current_customer_id
from app.schemas.customer import (
    OfflineQrResponse,
    PaymentMethodCreate,
    PaymentMethodResponse,
    TransactionHistoryResponse,
    VehicleCreate,
    VehicleResponse,
)
from app.services.customer_service import (
    add_vehicle,
    create_offline_qr,
    get_transaction_history,
    link_payment_method,
)

router = APIRouter(prefix="/customer", tags=["Customer – Mobile App"])


@router.get(
    "/history",
    response_model=TransactionHistoryResponse,
    summary="Fetch Transaction History (Tra cứu lịch sử)",
    description="Returns a paginated list of all fuel transactions for the authenticated customer.",
)
async def get_history(
    customer_id: Annotated[uuid.UUID, Depends(get_current_customer_id)],
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    db: AsyncSession = Depends(get_db),
) -> TransactionHistoryResponse:
    return await get_transaction_history(customer_id, page, page_size, db)


@router.get(
    "/history/dev",
    response_model=TransactionHistoryResponse,
    summary="[DEV] Fetch Transaction History by phone (no auth)",
    description=(
        "**Development only** – look up transactions by customer phone number. "
        "Remove this endpoint before deploying to production."
    ),
    tags=["Customer – Mobile App"],
)
async def get_history_dev(
    phone: str = Query(..., examples=["0901234567"], description="Customer phone number"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
) -> TransactionHistoryResponse:
    from sqlalchemy import select
    from app.models import Customer as CustomerModel

    result = await db.execute(
        select(CustomerModel).where(CustomerModel.phone == phone)
    )
    customer = result.scalar_one_or_none()
    if not customer:
        from app.core.exceptions import NotFoundException
        raise NotFoundException("Customer")
    return await get_transaction_history(customer.id, page, page_size, db)


@router.post(
    "/vehicles",
    response_model=VehicleResponse,
    status_code=201,
    summary="Register Vehicle / License Plate (Quản lý phương tiện)",
    description="Registers a new vehicle license plate to the authenticated customer's account.",
)
async def register_vehicle(
    payload: VehicleCreate,
    customer_id: Annotated[uuid.UUID, Depends(get_current_customer_id)],
    db: AsyncSession = Depends(get_db),
) -> VehicleResponse:
    return await add_vehicle(customer_id, payload, db)


@router.post(
    "/payment-methods",
    response_model=PaymentMethodResponse,
    status_code=201,
    summary="Link Payment Method (Liên kết thanh toán)",
    description=(
        "Links a new payment method (card / e-wallet) to the customer account "
        "using a tokenised gateway reference. The gateway token is obtained from "
        "the payment provider's SDK on the client side."
    ),
)
async def link_payment(
    payload: PaymentMethodCreate,
    customer_id: Annotated[uuid.UUID, Depends(get_current_customer_id)],
    db: AsyncSession = Depends(get_db),
) -> PaymentMethodResponse:
    return await link_payment_method(customer_id, payload, db)


@router.get(
    "/offline-qr",
    response_model=OfflineQrResponse,
    summary="Generate Offline QR Code (Tạo QR Offline)",
    description=(
        "Generates a short-lived, signed QR code for customers in areas with "
        "no internet connection. The QR encodes a signed JWT valid for "
        f"5 minutes, which staff can scan to process a manual payment."
    ),
)
async def get_offline_qr(
    customer_id: Annotated[uuid.UUID, Depends(get_current_customer_id)],
    db: AsyncSession = Depends(get_db),
) -> OfflineQrResponse:
    return await create_offline_qr(customer_id, db)
