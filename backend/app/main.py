"""
FastAPI application factory – main entry point.
"""
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.database import engine, Base
from app.core.exceptions import register_exception_handlers
from app.routers import admin, customer, engine as engine_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Create DB tables on startup (use Alembic in production)."""
    import app.models  # noqa: F401 – register all ORM models
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as exc:  # PostgreSQL not reachable
        import logging
        logging.getLogger("uvicorn.error").warning(
            "⚠️  Could not connect to PostgreSQL on startup – running without DB. "
            f"Error: {exc}"
        )
    yield
    await engine.dispose()


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description=(
            "## Smart Refuel System – Backend API\n\n"
            "A fully automated, AI-powered payment system for gas stations.\n\n"
            "### Modules\n"
            "- **Engine** `/api/v1/engine` – AI camera & IoT pump integration, auto-payment pipeline\n"
            "- **Customer** `/api/v1/customer` – Mobile customer features (history, vehicles, QR)\n"
            "- **Admin** `/api/v1/admin` – Dashboard analytics, AI monitoring, staff QR scan\n"
        ),
        openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
        docs_url=f"{settings.API_V1_PREFIX}/docs",
        redoc_url=f"{settings.API_V1_PREFIX}/redoc",
        lifespan=lifespan,
    )

    # ── CORS ──────────────────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Exception handlers ────────────────────────────────────────────
    register_exception_handlers(app)

    # ── Routers ───────────────────────────────────────────────────────
    api_prefix = settings.API_V1_PREFIX
    app.include_router(engine_router.router, prefix=api_prefix)
    app.include_router(customer.router, prefix=api_prefix)
    app.include_router(admin.router, prefix=api_prefix)

    @app.get("/", tags=["Health"], summary="Health Check")
    async def health_check():
        return {
            "status": "ok",
            "app": settings.APP_NAME,
            "version": settings.APP_VERSION,
        }

    return app


app = create_app()
