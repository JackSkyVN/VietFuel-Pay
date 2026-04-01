# -*- coding: utf-8 -*-
"""
seed_db.py - Populate the smart_refuel database with realistic mock data.

Usage (from the backend/ directory with .venv activated):
    python seed_db.py

Features:
  - Idempotent: safe to run multiple times (upserts by phone / license plate).
  - Creates:
      1 Customer      -> Thanh Nguyen  (phone: 0901234567)
      1 Vehicle       -> 51G-123.45   (Honda Air Blade)
      1 PaymentMethod -> VISA *4242
      3 Transactions  -> SUCCESS (AI auto-pay, VISA card)
      3 AI logs       -> matching the transactions for audit trail
"""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
import asyncio
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# ── Load settings ─────────────────────────────────────────────────────────────
from app.core.config import get_settings
from app.core.security import hash_password
from app.models import (
    AiRecognitionLog,
    Customer,
    LinkedPaymentMethod,
    PaymentMethod,
    Transaction,
    TransactionStatus,
    Vehicle,
)

settings = get_settings()

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionFactory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


# ── Helpers ───────────────────────────────────────────────────────────────────

def utc(days_ago: int = 0, hours_ago: int = 0) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=days_ago, hours=hours_ago)


# ── Seed data definitions ─────────────────────────────────────────────────────

CUSTOMER_PHONE = "0901234567"

MOCK_STATIONS = [
    {"station_id": "STN-001", "pump_id": "PUMP-01", "name": "Viettel Station — Q.1"},
    {"station_id": "STN-002", "pump_id": "PUMP-03", "name": "Shell Cộng Hòa"},
    {"station_id": "STN-003", "pump_id": "PUMP-02", "name": "Viettel Station — Q.7"},
]

MOCK_TRANSACTIONS = [
    {
        "fuel_liters": 8.5,
        "amount_vnd": 180_000.0,
        "station": MOCK_STATIONS[0],
        "days_ago": 0,
        "hours_ago": 2,
        "gateway_ref": "GW-REF-A1B2C3",
    },
    {
        "fuel_liters": 11.2,
        "amount_vnd": 245_000.0,
        "station": MOCK_STATIONS[1],
        "days_ago": 1,
        "hours_ago": 0,
        "gateway_ref": "GW-REF-D4E5F6",
    },
    {
        "fuel_liters": 4.5,
        "amount_vnd": 95_000.0,
        "station": MOCK_STATIONS[2],
        "days_ago": 2,
        "hours_ago": 0,
        "gateway_ref": "GW-REF-G7H8I9",
    },
]


# ── Main seeder ───────────────────────────────────────────────────────────────

async def seed() -> None:
    async with AsyncSessionFactory() as db:
        print("[SEED] Starting database seed...\n")

        # ── 1. Customer ───────────────────────────────────────────────────────
        existing = (
            await db.execute(select(Customer).where(Customer.phone == CUSTOMER_PHONE))
        ).scalar_one_or_none()

        if existing:
            customer = existing
            print(f"[OK]  Customer already exists -> {customer.full_name} ({customer.id})")
        else:
            customer = Customer(
                id=uuid.uuid4(),
                full_name="Thanh Nguyễn",
                phone=CUSTOMER_PHONE,
                email="thanh.nguyen@vietfuel.vn",
                hashed_password=hash_password("Demo@1234"),
                is_active=True,
                created_at=utc(days_ago=30),
            )
            db.add(customer)
            await db.flush()
            print(f"[OK]  Created customer -> {customer.full_name} ({customer.id})")

        # ── 2. Vehicle ────────────────────────────────────────────────────────
        PLATE = "51G-123.45"
        existing_vehicle = (
            await db.execute(select(Vehicle).where(Vehicle.license_plate == PLATE))
        ).scalar_one_or_none()

        if existing_vehicle:
            vehicle = existing_vehicle
            print(f"[OK]  Vehicle already exists -> {vehicle.license_plate}")
        else:
            vehicle = Vehicle(
                id=uuid.uuid4(),
                customer_id=customer.id,
                license_plate=PLATE,
                make="Honda",
                model="Air Blade 160",
                is_primary=True,
                created_at=utc(days_ago=25),
            )
            db.add(vehicle)
            await db.flush()
            print(f"[OK]  Created vehicle -> {vehicle.license_plate}")

        # ── 3. Payment method ─────────────────────────────────────────────────
        existing_pm = (
            await db.execute(
                select(LinkedPaymentMethod).where(
                    LinkedPaymentMethod.customer_id == customer.id
                )
            )
        ).scalar_one_or_none()

        if existing_pm:
            payment_method = existing_pm
            print(f"[OK]  Payment method already exists -> {payment_method.provider} {payment_method.masked_account}")
        else:
            payment_method = LinkedPaymentMethod(
                id=uuid.uuid4(),
                customer_id=customer.id,
                provider="VISA",
                masked_account="**** **** **** 4242",
                gateway_token="tok_sandbox_vietfuel_4242",
                is_default=True,
                created_at=utc(days_ago=20),
            )
            db.add(payment_method)
            await db.flush()
            print("[OK]  Created payment method -> VISA *4242")

        # ── 4. Transactions + AI logs ─────────────────────────────────────────
        print("\n[SEED] Seeding transactions...")
        for i, tx_data in enumerate(MOCK_TRANSACTIONS):
            st = tx_data["station"]
            tx_time = utc(days_ago=tx_data["days_ago"], hours_ago=tx_data["hours_ago"])

            # Check idempotency by gateway_reference
            existing_tx = (
                await db.execute(
                    select(Transaction).where(
                        Transaction.gateway_reference == tx_data["gateway_ref"]
                    )
                )
            ).scalar_one_or_none()

            if existing_tx:
                print(f"   [SKIP] Transaction #{i+1} already exists -> {tx_data['gateway_ref']}")
                continue

            transaction = Transaction(
                id=uuid.uuid4(),
                customer_id=customer.id,
                license_plate=PLATE,
                fuel_liters=tx_data["fuel_liters"],
                amount_vnd=tx_data["amount_vnd"],
                status=TransactionStatus.SUCCESS,
                payment_method=PaymentMethod.LINKED_CARD,
                gateway_reference=tx_data["gateway_ref"],
                geofence_validated=True,
                station_id=st["station_id"],
                pump_id=st["pump_id"],
                created_at=tx_time,
                completed_at=tx_time + timedelta(seconds=4),
            )
            db.add(transaction)

            # Matching AI recognition log
            ai_log = AiRecognitionLog(
                id=uuid.uuid4(),
                license_plate=PLATE,
                confidence_score=round(0.95 + i * 0.01, 2),
                raw_image_url=f"https://cdn.smartrefuel.vn/captures/{PLATE.replace('-','_')}_{i+1}.jpg",
                station_id=st["station_id"],
                camera_id=f"CAM-{st['pump_id'][-2:]}",
                processed=True,
                created_at=tx_time - timedelta(seconds=2),
            )
            db.add(ai_log)

            print(
                f"   [OK] Transaction #{i+1}: {st['name']} "
                f"| {tx_data['fuel_liters']}L"
                f"| VND {tx_data['amount_vnd']:,.0f}"
                f"| {tx_data['gateway_ref']}"
            )

        await db.commit()

    print("\n[DONE] Seed completed successfully!")
    print(f"\n   Customer phone   : {CUSTOMER_PHONE}")
    print(f"   Customer password: Demo@1234")
    print(f"   License plate    : {PLATE}")
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
