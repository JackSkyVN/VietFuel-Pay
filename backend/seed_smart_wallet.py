"""
seed_smart_wallet.py
--------------------
Seeds a demo Customer with a pre-loaded wallet and a linked PENDING
Transaction so you can immediately test the Smart Wallet payment flow.

Usage (from the /backend directory, venv activated):
    python seed_smart_wallet.py

What it creates
---------------
  customers table:
    id             = "00000000-0000-0000-0000-000000000123"
    full_name      = "Demo User"
    phone          = "+84-demo-0001"
    wallet_balance = 1_000_000  (1,000,000 VND)

  transactions table:
    id             = "00000000-0000-0000-0000-000000000abc"
    customer_id    = (above customer)
    license_plate  = "29A-123.45"
    status         = PENDING
    payment_method = LINKED_CARD

Re-running the script is safe - it UPSERTs both rows.
"""

import asyncio
import uuid
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.models import Customer, Transaction, TransactionStatus, PaymentMethod

DEMO_CUSTOMER_ID = uuid.UUID("00000000-0000-0000-0000-000000000123")
DEMO_TXN_ID      = uuid.UUID("00000000-0000-0000-0000-000000000abc")
DEMO_PLATE       = "29A-123.45"
DEMO_BALANCE     = 1_000_000

# Pre-computed bcrypt hash of "demo1234" - avoids passlib/bcrypt version noise
DEMO_HASHED_PW = "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW"


async def seed() -> None:
    settings = get_settings()
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    Session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with Session() as db:
        # Customer
        existing_customer = await db.get(Customer, DEMO_CUSTOMER_ID)
        if existing_customer:
            existing_customer.wallet_balance = DEMO_BALANCE
            print(f"[UPDATE] Customer {DEMO_CUSTOMER_ID} wallet_balance -> {DEMO_BALANCE:,} VND")
        else:
            db.add(Customer(
                id=DEMO_CUSTOMER_ID,
                full_name="Demo User",
                phone="+84-demo-0001",
                email="demo@smartrefuel.vn",
                hashed_password=DEMO_HASHED_PW,
                wallet_balance=DEMO_BALANCE,
                is_active=True,
            ))
            print(f"[CREATE] Customer {DEMO_CUSTOMER_ID}  balance={DEMO_BALANCE:,} VND")

        await db.flush()

        # Transaction
        existing_txn = await db.get(Transaction, DEMO_TXN_ID)
        if existing_txn:
            existing_txn.status = TransactionStatus.PENDING
            existing_txn.amount_vnd = 0.0
            existing_txn.completed_at = None
            print(f"[RESET]  Transaction {DEMO_TXN_ID} -> PENDING")
        else:
            db.add(Transaction(
                id=DEMO_TXN_ID,
                customer_id=DEMO_CUSTOMER_ID,
                license_plate=DEMO_PLATE,
                fuel_liters=0.0,
                amount_vnd=0.0,
                status=TransactionStatus.PENDING,
                payment_method=PaymentMethod.LINKED_CARD,
                geofence_validated=True,
                station_id="STN-DEMO",
                pump_id="PUMP-DEMO",
            ))
            print(f"[CREATE] Transaction {DEMO_TXN_ID}  plate={DEMO_PLATE}  status=PENDING")

        await db.commit()

    await engine.dispose()
    print("\n--- Done! Smart Wallet demo data is ready. ---")
    print(f"  transaction_id : {DEMO_TXN_ID}")
    print(f"  license plate  : {DEMO_PLATE}")
    print(f"  wallet balance : {DEMO_BALANCE:,} VND")


if __name__ == "__main__":
    asyncio.run(seed())
