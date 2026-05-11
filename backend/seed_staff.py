"""
seed_staff.py
─────────────
Creates the staff_members and shift_transactions tables (via SQLAlchemy
create_all), then seeds demo staff accounts and today's shift transactions.

Usage (from the backend/ directory with venv activated):
    python seed_staff.py

Demo accounts created
─────────────────────
Role        | Phone          | Employee Code | Password
------------|----------------|---------------|----------
Cashier     | 0901111001     | NV001         | Staff@1234
Cashier     | 0901111002     | NV002         | Staff@1234
Supervisor  | 0901111010     | GS001         | Staff@1234
Manager     | 0901111020     | QL001         | Staff@1234
"""
import asyncio
import random
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# ── Config ────────────────────────────────────────────────────────────────────
try:
    from dotenv import load_dotenv
    import os
    load_dotenv()
    DATABASE_URL = os.environ.get(
        "DATABASE_URL",
        "postgresql+asyncpg://postgres:postgres@localhost:5432/smart_refuel",
    )
except ImportError:
    DATABASE_URL = "postgresql+asyncpg://postgres:postgres@localhost:5432/smart_refuel"

# ── Demo staff data ───────────────────────────────────────────────────────────
STAFF_SEED = [
    dict(full_name="Nguyễn Văn Hùng",    phone="0901111001", employee_code="NV001", role="CASHIER",    password="Staff@1234"),
    dict(full_name="Trần Thị Lan",        phone="0901111002", employee_code="NV002", role="CASHIER",    password="Staff@1234"),
    dict(full_name="Lê Quang Vinh",       phone="0901111010", employee_code="GS001", role="SUPERVISOR", password="Staff@1234"),
    dict(full_name="Phạm Minh Quân",      phone="0901111020", employee_code="QL001", role="MANAGER",    password="Staff@1234"),
]

PLATES = [
    "29A-12345", "51G-88821", "30F-56789", "43A-11002", "92C-34400",
    "30K-20911", "29B-77643", "51F-00123", "30E-45001", "29D-99001",
    "43B-55200", "92A-10020", "30A-87654", "51H-44321", "29C-11111",
]
AMOUNTS = [200_000, 280_000, 350_000, 420_000, 470_000, 500_000,
           600_000, 750_000, 800_000, 950_000, 1_500_000, 3_200_000]
METHODS = ["CASH", "QR", "CARD"]


async def main() -> None:
    engine = create_async_engine(DATABASE_URL, echo=False)

    # Import models so Base.metadata is populated
    from app.models import Base, StaffMember, ShiftTransaction  # noqa: F401
    from app.core.security import hash_password

    # Create tables that don't exist yet (safe – skips existing ones)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("✅  Tables ensured (staff_members, shift_transactions).")

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # ── Staff members ──────────────────────────────────────────────────────
        now = datetime.now(timezone.utc)
        created_staff = []

        for s in STAFF_SEED:
            # Check if already exists (idempotent)
            existing = await session.execute(
                text("SELECT id FROM staff_members WHERE phone = :phone"),
                {"phone": s["phone"]},
            )
            row = existing.fetchone()
            if row:
                staff_id = row[0]
                print(f"  ⏭  Staff {s['phone']} already exists – skipping.")
            else:
                staff_id = uuid.uuid4()
                await session.execute(
                    text("""
                        INSERT INTO staff_members
                            (id, full_name, phone, employee_code, hashed_password,
                             role, is_active, created_at)
                        VALUES
                            (:id, :full_name, :phone, :employee_code,
                             :hashed_password, :role, true, :created_at)
                    """),
                    {
                        "id": staff_id,
                        "full_name": s["full_name"],
                        "phone": s["phone"],
                        "employee_code": s["employee_code"],
                        "hashed_password": hash_password(s["password"]),
                        "role": s["role"],
                        "created_at": now,
                    },
                )
                print(f"  ✅  Created {s['role']:10s} {s['full_name']} ({s['employee_code']})")
            created_staff.append(staff_id)

        await session.commit()

        # ── Shift transactions (today, spread over 8 hours) ──────────────────
        # Use only the two cashier accounts (first two)
        cashier_ids = created_staff[:2]
        shift_start = now.replace(hour=6, minute=0, second=0, microsecond=0)

        tx_count = 0
        for i, plate in enumerate(PLATES):
            tx_time = shift_start + timedelta(minutes=random.randint(i * 15, i * 15 + 14))
            pump = random.randint(1, 4)
            amount = random.choice(AMOUNTS)
            method = random.choice(METHODS)
            staff_id = random.choice(cashier_ids)

            await session.execute(
                text("""
                    INSERT INTO shift_transactions
                        (id, staff_id, license_plate, pump_number,
                         amount_vnd, payment_method, created_at)
                    VALUES
                        (:id, :staff_id, :license_plate, :pump_number,
                         :amount_vnd, :payment_method, :created_at)
                """),
                {
                    "id": uuid.uuid4(),
                    "staff_id": staff_id,
                    "license_plate": plate,
                    "pump_number": pump,
                    "amount_vnd": amount,
                    "payment_method": method,
                    "created_at": tx_time,
                },
            )
            tx_count += 1

        await session.commit()
        print(f"\n🏁  Seeded {tx_count} shift transactions for today.")

    await engine.dispose()

    print("\n📋  Demo Staff Login Credentials")
    print("─" * 58)
    print(f"{'Role':<12} {'Phone':<15} {'Code':<8} {'Password'}")
    print("─" * 58)
    for s in STAFF_SEED:
        print(f"{s['role']:<12} {s['phone']:<15} {s['employee_code']:<8} {s['password']}")
    print("─" * 58)
    print("\n✨  Done!  Use POST /api/v1/auth/staff-login to authenticate.")


if __name__ == "__main__":
    asyncio.run(main())
