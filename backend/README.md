# Smart Refuel System – Backend API

**FastAPI** · **PostgreSQL** · **asyncpg** · **SQLAlchemy (async)** · **Pydantic v2** · **Alembic**

---

## Quick Start

```bash
# 1. Enter the backend directory
cd backend

# 2. Create & activate a virtual environment
python -m venv .venv
.venv\Scripts\activate        # Windows PowerShell

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment
copy .env.example .env        # then edit .env with your DB credentials

# 5. Run database migrations (first time)
alembic upgrade head

# 6. Start the dev server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Interactive API docs: **http://localhost:8000/api/v1/docs**

---

## Project Structure

```
backend/
├── alembic/                   # Database migrations
│   ├── env.py                 # Async Alembic configuration
│   └── script.py.mako
├── alembic.ini
├── app/
│   ├── main.py                # FastAPI application factory
│   ├── dependencies.py        # JWT auth dependency injection
│   ├── core/
│   │   ├── config.py          # Pydantic settings (env vars)
│   │   ├── database.py        # Async SQLAlchemy engine + session
│   │   ├── exceptions.py      # Domain exceptions + handlers
│   │   └── security.py        # JWT + password hashing
│   ├── models/
│   │   └── __init__.py        # All ORM models (6 tables)
│   ├── routers/
│   │   ├── engine.py          # /api/v1/engine endpoints
│   │   ├── customer.py        # /api/v1/customer endpoints
│   │   └── admin.py           # /api/v1/admin endpoints
│   ├── schemas/
│   │   ├── engine.py          # Pydantic I/O schemas – engine
│   │   ├── customer.py        # Pydantic I/O schemas – customer
│   │   └── admin.py           # Pydantic I/O schemas – admin
│   ├── services/
│   │   ├── engine_service.py  # Core payment pipeline logic
│   │   ├── customer_service.py
│   │   └── admin_service.py
│   └── utils/
│       ├── geofence.py        # Haversine geofence validation
│       ├── payment_gateway.py # External gateway HTTP client
│       └── qr_generator.py    # Signed JWT QR code generator
├── tests/
│   ├── conftest.py
│   ├── test_geofence.py
│   └── test_engine_router.py
├── requirements.txt
├── pytest.ini
└── .env.example
```

---

## API Endpoints

### Engine (`/api/v1/engine`)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/ai-trigger` | Receive AI camera scan (license plate + confidence score) |
| POST | `/iot-trigger` | Receive IoT gas pump data (fuel liters + amount) |

> Auto-payment pipeline fires internally when both triggers arrive for the same plate. Includes **Geofence validation** (Haversine) + **Payment Gateway** call.

### Customer (`/api/v1/customer`) – JWT required
| Method | Path | Description |
|--------|------|-------------|
| GET | `/history` | Paginated transaction history |
| POST | `/vehicles` | Register vehicle/license plate |
| POST | `/payment-methods` | Link card/e-wallet via gateway token |
| GET | `/offline-qr` | Generate 5-min dynamic QR code (Base64 PNG + JWT) |

### Admin (`/api/v1/admin`) – Admin/Staff JWT required
| Method | Path | Description |
|--------|------|-------------|
| POST | `/scan-offline-qr` | Staff scans customer QR & processes manual payment |
| GET | `/monitor-ai` | Paginated AI logs with confidence scores |
| GET | `/revenue` | Aggregated revenue stats + daily breakdown |

---

## Running Tests

```bash
pip install pytest pytest-asyncio
pytest
```
