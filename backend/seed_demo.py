# -*- coding: utf-8 -*-
"""
seed_demo.py – Bulk demo data generator for the smart_refuel PostgreSQL database.

Usage (from the backend/ directory with .venv activated):
    python seed_demo.py

What it creates:
  • 20 realistic Vietnamese customers (bcrypt-hashed password: Demo@1234)
  • 1–2 vehicles per customer  (random Vietnamese license plates)
  • 1–2 payment methods per customer  (VISA / MasterCard / MOMO / ZaloPay)
  • 5–15 transactions per customer spread across the last 90 days
  • 1 matching AiRecognitionLog per transaction
  • 1 OfflineQrToken per customer  (already-expired, realistic demo state)

Idempotent: Re-running skips rows that already exist (matched by phone / plate).
"""

import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

import asyncio
import random
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import (
    AiRecognitionLog,
    Customer,
    LinkedPaymentMethod,
    OfflineQrToken,
    PaymentMethod,
    Transaction,
    TransactionStatus,
    Vehicle,
)

# ─────────────────────────────────────────────────────────────────────────────
settings = get_settings()
engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionFactory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

DEMO_PASSWORD = "Demo@1234"
HASHED_PW = hash_password(DEMO_PASSWORD)

# ── Helpers ───────────────────────────────────────────────────────────────────

def utc_ago(days: float = 0, hours: float = 0, minutes: float = 0) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=days, hours=hours, minutes=minutes)


def rand_vnd(liters: float) -> float:
    """Realistic VND price: ~21,000–23,500 VND/litre (E5 RON92)."""
    price_per_litre = random.randint(21_000, 23_500)
    return round(liters * price_per_litre, -3)   # round to nearest 1,000₫


def rand_liters() -> float:
    return round(random.uniform(3.0, 25.0), 2)

# ── Static pools ──────────────────────────────────────────────────────────────

FIRST_NAMES = [
    "An", "Bảo", "Châu", "Dũng", "Hà", "Hiền", "Khoa", "Lan", "Linh",
    "Long", "Minh", "Nam", "Ngọc", "Phúc", "Phương", "Quân", "Sơn",
    "Thảo", "Thu", "Trang", "Tuấn", "Vy", "Yến",
]
LAST_NAMES = [
    "Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan",
    "Vũ", "Võ", "Đặng", "Bùi", "Đỗ", "Hồ", "Ngô", "Dương", "Lý",
]
MIDDLE_NAMES = ["Thị", "Văn", "Hữu", "Minh", "Đức", "Quốc", "Thành", "Ngọc", "Bảo"]

PROVIDERS = [
    ("VISA",        "**** **** **** {last4}", "vis"),
    ("MasterCard",  "**** **** **** {last4}", "mc"),
    ("MOMO",        "0{phone_suffix}",         "momo"),
    ("ZaloPay",     "0{phone_suffix}",         "zalo"),
]

STATIONS = [
    {"station_id": "STN-001", "pump_id": "PUMP-01", "name": "VietFuel — Quận 1"},
    {"station_id": "STN-002", "pump_id": "PUMP-02", "name": "VietFuel — Quận 3"},
    {"station_id": "STN-003", "pump_id": "PUMP-03", "name": "VietFuel — Quận 7"},
    {"station_id": "STN-004", "pump_id": "PUMP-04", "name": "Shell Cộng Hòa"},
    {"station_id": "STN-005", "pump_id": "PUMP-01", "name": "Petrolimex — Thủ Đức"},
    {"station_id": "STN-006", "pump_id": "PUMP-02", "name": "VietFuel — Bình Thạnh"},
    {"station_id": "STN-007", "pump_id": "PUMP-03", "name": "Shell Nguyễn Văn Linh"},
    {"station_id": "STN-008", "pump_id": "PUMP-05", "name": "Petrolimex — Gò Vấp"},
]

VEHICLE_MAKES_MODELS = [
    ("Honda",    ["Air Blade 160", "Wave Alpha", "Vision", "SH 160i", "Lead"]),
    ("Yamaha",   ["Exciter 155", "Grande", "NVX 155", "Janus", "Sirius"]),
    ("Suzuki",   ["Raider R150", "Burgman Street", "Address"]),
    ("Piaggio",  ["Vespa Primavera", "Vespa Sprint", "Liberty S"]),
    ("VinFast",  ["Klara S", "Theon S", "Evo200"]),
    ("Toyota",   ["Vios", "Camry", "Fortuner", "Corolla Cross"]),
    ("Hyundai",  ["Accent", "i10", "Tucson", "Creta"]),
    ("Kia",      ["Morning", "Soluto", "Seltos", "Cerato"]),
]

# Vietnamese plate codes by region
PLATE_CODES = [
    "29", "30", "51", "52", "53", "54", "55", "56", "57", "58",
    "59", "60", "61", "65", "70", "72", "74", "79", "92", "93",
]
PLATE_LETTERS = "ABCDEFGHJKLMNPQRSTUVXY"  # no I, O, W, Z


def gen_plate() -> str:
    """Generate a plausible Vietnamese license plate, e.g. '51G-123.45'."""
    code   = random.choice(PLATE_CODES)
    letter = random.choice(PLATE_LETTERS)
    series = f"{random.randint(100, 999)}.{random.randint(10, 99)}"
    return f"{code}{letter}-{series}"


def gen_phone() -> str:
    """Vietnamese mobile number starting with 09x / 07x / 08x."""
    prefix = random.choice(["090", "091", "093", "094", "096", "097", "098",
                             "070", "077", "078", "079", "081", "082", "083",
                             "084", "085", "086", "088", "089"])
    return prefix + "".join([str(random.randint(0, 9)) for _ in range(7)])


def gen_full_name() -> str:
    last   = random.choice(LAST_NAMES)
    middle = random.choice(MIDDLE_NAMES)
    first  = random.choice(FIRST_NAMES)
    return f"{last} {middle} {first}"


def gen_email(name: str, phone: str) -> str:
    safe = (
        name.lower()
        .replace("ả", "a").replace("ã", "a").replace("â", "a").replace("ă", "a")
        .replace("à", "a").replace("á", "a").replace("ạ", "a").replace("ấ", "a")
        .replace("ầ", "a").replace("ẩ", "a").replace("ẫ", "a").replace("ậ", "a")
        .replace("ắ", "a").replace("ặ", "a").replace("ặ", "a").replace("ằ", "a")
        .replace("ể", "e").replace("ê", "e").replace("è", "e").replace("é", "e")
        .replace("ẻ", "e").replace("ẽ", "e").replace("ẹ", "e").replace("ế", "e")
        .replace("ề", "e").replace("ệ", "e").replace("ễ", "e").replace("ệ", "e")
        .replace("ì", "i").replace("í", "i").replace("ị", "i").replace("ỉ", "i")
        .replace("ĩ", "i")
        .replace("ò", "o").replace("ó", "o").replace("ọ", "o").replace("ỏ", "o")
        .replace("õ", "o").replace("ô", "o").replace("ố", "o").replace("ồ", "o")
        .replace("ổ", "o").replace("ỗ", "o").replace("ộ", "o").replace("ơ", "o")
        .replace("ớ", "o").replace("ờ", "o").replace("ở", "o").replace("ỡ", "o")
        .replace("ợ", "o")
        .replace("ù", "u").replace("ú", "u").replace("ụ", "u").replace("ủ", "u")
        .replace("ũ", "u").replace("ư", "u").replace("ứ", "u").replace("ừ", "u")
        .replace("ử", "u").replace("ữ", "u").replace("ự", "u")
        .replace("ỳ", "y").replace("ý", "y").replace("ỵ", "y").replace("ỷ", "y")
        .replace("ỹ", "y")
        .replace("đ", "d")
        .replace(" ", ".")
    )
    domains = ["gmail.com", "yahoo.com", "outlook.com", "vietfuel.vn", "hotmail.com"]
    return f"{safe}.{phone[-4:]}@{random.choice(domains)}"


# ── Individual record builders ────────────────────────────────────────────────

async def build_customer(db: AsyncSession, phone: str, idx: int) -> Customer | None:
    """Create or skip a customer. Returns the Customer ORM object."""
    existing = (await db.execute(select(Customer).where(Customer.phone == phone))).scalar_one_or_none()
    if existing:
        print(f"   [SKIP] Customer #{idx:02d} already exists  ({phone})")
        return existing

    name = gen_full_name()
    c = Customer(
        id=uuid.uuid4(),
        full_name=name,
        phone=phone,
        email=gen_email(name, phone),
        hashed_password=HASHED_PW,
        is_active=True,
        created_at=utc_ago(days=random.randint(10, 365)),
    )
    db.add(c)
    await db.flush()
    print(f"   [NEW] Customer #{idx:02d}: {c.full_name}  |  {phone}  ({c.id})")
    return c


async def build_vehicles(db: AsyncSession, customer: Customer, used_plates: set[str]) -> list[Vehicle]:
    num = random.randint(1, 2)
    vehicles: list[Vehicle] = []

    for j in range(num):
        # generate a plate that doesn't collide
        for _ in range(20):
            plate = gen_plate()
            if plate not in used_plates:
                break

        existing_v = (await db.execute(select(Vehicle).where(Vehicle.license_plate == plate))).scalar_one_or_none()
        if existing_v:
            print(f"      [SKIP] Vehicle {plate} already exists")
            vehicles.append(existing_v)
            used_plates.add(plate)
            continue

        make, models = random.choice(VEHICLE_MAKES_MODELS)
        model = random.choice(models)
        v = Vehicle(
            id=uuid.uuid4(),
            customer_id=customer.id,
            license_plate=plate,
            make=make,
            model=model,
            is_primary=(j == 0),
            created_at=utc_ago(days=random.randint(5, 300)),
        )
        db.add(v)
        await db.flush()
        used_plates.add(plate)
        vehicles.append(v)
        print(f"      [NEW] Vehicle: {plate}  ({make} {model})")

    return vehicles


async def build_payment_methods(db: AsyncSession, customer: Customer) -> list[LinkedPaymentMethod]:
    num = random.randint(1, 2)
    methods: list[LinkedPaymentMethod] = []
    selected_providers = random.sample(PROVIDERS, k=min(num, len(PROVIDERS)))

    for k, (provider, mask_tmpl, prefix) in enumerate(selected_providers):
        last4  = f"{random.randint(1000, 9999)}"
        p_suf  = customer.phone[-7:]
        masked = mask_tmpl.format(last4=last4, phone_suffix=p_suf)
        token  = f"tok_{prefix}_{secrets.token_hex(12)}"

        existing_pm = (
            await db.execute(
                select(LinkedPaymentMethod).where(LinkedPaymentMethod.gateway_token == token)
            )
        ).scalar_one_or_none()
        if existing_pm:
            methods.append(existing_pm)
            continue

        pm = LinkedPaymentMethod(
            id=uuid.uuid4(),
            customer_id=customer.id,
            provider=provider,
            masked_account=masked,
            gateway_token=token,
            is_default=(k == 0),
            created_at=utc_ago(days=random.randint(1, 200)),
        )
        db.add(pm)
        await db.flush()
        methods.append(pm)
        print(f"      [NEW] Payment: {provider}  {masked}")

    return methods


async def build_transactions(
    db: AsyncSession,
    customer: Customer,
    vehicles: list[Vehicle],
) -> int:
    num_tx = random.randint(5, 15)
    created_count = 0

    # Weight transaction statuses to look realistic
    status_pool = (
        [TransactionStatus.SUCCESS] * 14
        + [TransactionStatus.FAILED] * 2
        + [TransactionStatus.PENDING] * 1
        + [TransactionStatus.REFUNDED] * 1
    )
    pm_method_pool = (
        [PaymentMethod.LINKED_CARD] * 12
        + [PaymentMethod.OFFLINE_QR] * 4
        + [PaymentMethod.MANUAL] * 2
    )

    for _ in range(num_tx):
        vehicle    = random.choice(vehicles)
        station    = random.choice(STATIONS)
        tx_status  = random.choice(status_pool)
        pm_type    = random.choice(pm_method_pool)
        liters     = rand_liters()
        amount     = rand_vnd(liters)
        days_ago   = random.uniform(0, 90)
        tx_time    = utc_ago(days=days_ago)
        gw_ref     = f"GW-{secrets.token_hex(8).upper()}"

        # Idempotency: gateway_reference is unique enough for demo purposes
        existing_tx = (
            await db.execute(select(Transaction).where(Transaction.gateway_reference == gw_ref))
        ).scalar_one_or_none()
        if existing_tx:
            continue

        tx = Transaction(
            id=uuid.uuid4(),
            customer_id=customer.id,
            license_plate=vehicle.license_plate,
            fuel_liters=liters,
            amount_vnd=amount,
            status=tx_status,
            payment_method=pm_type,
            gateway_reference=gw_ref,
            geofence_validated=random.random() > 0.05,  # 95% validated
            station_id=station["station_id"],
            pump_id=station["pump_id"],
            created_at=tx_time,
            completed_at=(tx_time + timedelta(seconds=random.randint(3, 12)))
            if tx_status in (TransactionStatus.SUCCESS, TransactionStatus.REFUNDED)
            else None,
        )
        db.add(tx)

        # Matching AI recognition log
        ai_log = AiRecognitionLog(
            id=uuid.uuid4(),
            license_plate=vehicle.license_plate,
            confidence_score=round(random.uniform(0.82, 0.99), 3),
            raw_image_url=(
                f"https://cdn.vietfuel.vn/captures/"
                f"{vehicle.license_plate.replace('-','_').replace('.','_')}"
                f"_{secrets.token_hex(4)}.jpg"
            ),
            station_id=station["station_id"],
            camera_id=f"CAM-{station['pump_id'][-2:]}",
            processed=(tx_status != TransactionStatus.PENDING),
            created_at=tx_time - timedelta(seconds=random.randint(1, 5)),
        )
        db.add(ai_log)
        created_count += 1

    return created_count


async def build_offline_qr(db: AsyncSession, customer: Customer) -> None:
    """One already-expired offline QR token per customer for realistic demo data."""
    token = f"offqr_{secrets.token_urlsafe(32)}"
    qt = OfflineQrToken(
        id=uuid.uuid4(),
        customer_id=customer.id,
        token=token,
        expires_at=utc_ago(days=random.randint(1, 30)),   # already expired
        is_used=random.random() > 0.3,                     # 70% used
        created_at=utc_ago(days=random.randint(2, 60)),
    )
    db.add(qt)


# ── Main seeder ───────────────────────────────────────────────────────────────

NUM_CUSTOMERS = 20

async def seed() -> None:
    print("=" * 62)
    print("  VietFuel Pay — Bulk Demo Seeder")
    print(f"  Generating {NUM_CUSTOMERS} accounts  |  password: {DEMO_PASSWORD}")
    print("=" * 62 + "\n")

    used_phones: set[str] = set()
    used_plates: set[str] = set()

    # Reserve the original demo account phone so we don't collide
    used_phones.add("0901234567")

    total_tx = 0

    async with AsyncSessionFactory() as db:
        for idx in range(1, NUM_CUSTOMERS + 1):
            # Unique phone
            for _ in range(50):
                phone = gen_phone()
                if phone not in used_phones:
                    used_phones.add(phone)
                    break

            print(f"\n── Account {idx:02d} / {NUM_CUSTOMERS} ─────────────────────────────")
            customer = await build_customer(db, phone, idx)
            if customer is None:
                continue

            vehicles = await build_vehicles(db, customer, used_plates)
            await build_payment_methods(db, customer)
            tx_count = await build_transactions(db, customer, vehicles)
            await build_offline_qr(db, customer)

            total_tx += tx_count

        await db.commit()

    print("\n" + "=" * 62)
    print(f"  [DONE] Seed complete!")
    print(f"  Customers  : {NUM_CUSTOMERS}")
    print(f"  Transactions created (approx): {total_tx}")
    print(f"  Login password for all accounts: {DEMO_PASSWORD}")
    print("=" * 62)

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
