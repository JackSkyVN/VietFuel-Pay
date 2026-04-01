"""
Application settings loaded from environment variables via pydantic-settings.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── App ───────────────────────────────────────────────────────────
    APP_NAME: str = "Smart Refuel System API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"

    # ── Database ──────────────────────────────────────────────────────
    DATABASE_URL: str = "postgresql+asyncpg://postgres:password@localhost:5432/smart_refuel"

    # ── Security ──────────────────────────────────────────────────────
    SECRET_KEY: str = "change-me-in-production-use-openssl-rand-hex-32"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 1 day
    ALGORITHM: str = "HS256"

    # ── Payment Gateway (External) ────────────────────────────────────
    PAYMENT_GATEWAY_URL: str = "https://sandbox.payment-gateway.vn/api/charge"
    PAYMENT_GATEWAY_API_KEY: str = "sandbox-key"

    # ── Geofence ──────────────────────────────────────────────────────
    # Allowed radius in metres around the station centre
    GEOFENCE_RADIUS_METERS: float = 300.0
    STATION_LAT: float = 10.7769  # Default: Ho Chi Minh City demo coordinates
    STATION_LON: float = 106.7009

    # ── QR Code ───────────────────────────────────────────────────────
    QR_EXPIRY_SECONDS: int = 300  # 5-minute TTL for offline QR tokens

    # ── CORS ──────────────────────────────────────────────────────────
    CORS_ORIGINS: list[str] = ["*"]


@lru_cache
def get_settings() -> Settings:
    """Cached singleton – call this everywhere to access config."""
    return Settings()
