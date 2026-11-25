"""Application settings loaded from environment variables."""

import secrets
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


def _ephemeral_dev_key() -> str:
    return secrets.token_hex(32)


class Settings(BaseSettings):
    """Typed environment configuration for VeloFleet backend."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "VeloFleet API"
    app_env: str = "development"
    debug: bool = False
    api_v1_prefix: str = "/api/v1"

    database_url: str = (
        "postgresql+asyncpg://velofleet:velofleet_dev_change_me@localhost:5433/velofleet"
    )
    test_database_url: str = (
        "postgresql+asyncpg://velofleet:velofleet_dev_change_me@localhost:5433/velofleet_test"
    )
    redis_url: str = "redis://localhost:6379/0"
    test_redis_url: str = "redis://localhost:6379/1"

    jwt_secret_key: str = Field(default_factory=_ephemeral_dev_key, min_length=32)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 14
    mfa_encryption_key: str = ""

    cors_allow_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:8080", "http://127.0.0.1:8080"]
    )
    cors_allow_origin_regex: str | None = None
    max_request_body_bytes: int = 12_582_912

    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_bucket_name: str = "velofleet-assets"
    s3_region: str = "us-east-1"
    s3_public_base_url: str = "http://localhost:9000/velofleet-assets"

    default_currency: str = "USD"
    default_timezone: str = "UTC"
    gps_retention_days: int = 90
    sentry_dsn: str = ""


@lru_cache
def get_settings() -> Settings:
    """Return cached application settings instance."""
    return Settings()
