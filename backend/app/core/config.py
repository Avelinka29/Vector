from functools import lru_cache
from typing import Annotated

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="VECTOR_",
        case_sensitive=False,
        extra="ignore",
    )

    environment: str = "development"
    database_url: str = "postgresql+asyncpg://vector:vector@localhost:5432/vector"
    jwt_secret: str = Field(default="development-only-change-this-secret", min_length=32)
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    allowed_origins: Annotated[list[str], NoDecode] = ["http://localhost:3000"]
    first_admin_email: str | None = None
    first_admin_password: str | None = None
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_from_email: str = "support@vector.by"
    smtp_use_tls: bool = True
    public_app_url: str = "vector://auth"

    @field_validator("allowed_origins", mode="before")
    @classmethod
    def parse_origins(cls, value: object) -> object:
        if isinstance(value, str) and not value.startswith("["):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
