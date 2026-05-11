"""
FastAPI application factory – main entry point.
"""
import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.database import engine as db_engine, Base
from app.core.exceptions import register_exception_handlers
from app.routers import admin as admin_router
from app.routers import auth as auth_router
from app.routers import customer as customer_router
from app.routers import engine as engine_router
from app.routers import staff as staff_router
from app.routers import stations as stations_router
from app.routers import transactions as transactions_router

settings = get_settings()
logger = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Create DB tables on startup (use Alembic in production)."""
    import app.models  # noqa: F401 – register all ORM models with SQLAlchemy
    try:
        async with db_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("✅  Database tables verified/created on startup.")
    except Exception as exc:  # PostgreSQL not reachable at startup
        logger.warning(
            "⚠️  Could not connect to PostgreSQL on startup – running without DB. "
            f"Error: {exc}"
        )
    yield
    await db_engine.dispose()
    logger.info("🛑  Database engine disposed.")


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description=(
            "## Smart Refuel System – Backend API\n\n"
            "A fully automated, AI-powered payment system for gas stations.\n\n"
            "### Modules\n"
            "- **Auth** `/api/v1/auth` – Unified login (customer + staff), registration\n"
            "- **Engine** `/api/v1/engine` – AI camera & IoT pump integration\n"
            "- **Customer** `/api/v1/customer` – Mobile customer features (history, vehicles, QR)\n"
            "- **Staff** `/api/v1/staff` – POS shift dashboard & transaction recording\n"
            "- **Stations** `/api/v1/stations` – Gas station map data\n"
            "- **Admin** `/api/v1/admin` – Dashboard analytics & AI monitoring\n"
        ),
        openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
        docs_url=f"{settings.API_V1_PREFIX}/docs",
        redoc_url=f"{settings.API_V1_PREFIX}/redoc",
        lifespan=lifespan,
    )

    # ── CORS ───────────────────────────────────────────────────────────────────
    # Allow all origins for development. Restrict to specific origins in production.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Exception handlers ─────────────────────────────────────────────────────
    register_exception_handlers(app)

    # ── Routers ────────────────────────────────────────────────────────────────
    prefix = settings.API_V1_PREFIX
    app.include_router(auth_router.router,         prefix=prefix)
    app.include_router(engine_router.router,       prefix=prefix)
    app.include_router(customer_router.router,     prefix=prefix)
    app.include_router(admin_router.router,        prefix=prefix)
    app.include_router(stations_router.router,     prefix=prefix)
    app.include_router(transactions_router.router, prefix=prefix)
    app.include_router(staff_router.router,        prefix=prefix)

    # ── Health check ───────────────────────────────────────────────────────────
    @app.get("/", tags=["Health"], summary="Health Check")
    async def health_check():
        return {
            "status": "ok",
            "app": settings.APP_NAME,
            "version": settings.APP_VERSION,
        }

    return app


app = create_app()
