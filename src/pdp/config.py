"""Environment-driven configuration for the procurement data platform."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings sourced from environment variables / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql://pdp:pdp@localhost:5432/pdp"  # pragma: allowlist secret


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
