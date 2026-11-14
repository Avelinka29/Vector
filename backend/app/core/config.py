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
    smtp_use_ssl: bool = False
    email_transport: str = "smtp"
    gmail_client_id: str = ""
    gmail_client_secret: str = ""
    gmail_refresh_token: str = ""
    web_app_url: str = "http://localhost:4173"
    public_app_url: str = "vector://auth"
    openrouter_api_key: str | None = None
    openrouter_model: str = "openrouter/free"
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    openrouter_app_name: str = "VECTOR"
    assistant_timeout_seconds: float = 45.0
    upload_directory: str = "/data/uploads"
    max_upload_bytes: int = 10_485_760
    firebase_service_account_path: str | None = None
    google_client_id: str = ""

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
