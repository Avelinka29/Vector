from pydantic import BaseModel, EmailStr, Field, field_validator

from app.models.enums import UserRole, UserStatus


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=2, max_length=200)
    role: UserRole = UserRole.APPLICANT


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def local_admin_alias(cls, value):
        from app.core.config import settings
        from app.commands.demo_admin import DEMO_ADMIN_EMAIL
        if isinstance(value, str) and value.strip().casefold() in {"admin", DEMO_ADMIN_EMAIL}:
            if settings.environment != "development":
                raise ValueError("Демонстрационный вход доступен только на локальном сервере")
            return DEMO_ADMIN_EMAIL
        return value


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=1, max_length=16384)
    role: UserRole = UserRole.APPLICANT


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class EmailRequest(BaseModel):
    email: EmailStr


class ActionTokenRequest(BaseModel):
    token: str = Field(min_length=20)


class PasswordResetConfirmRequest(ActionTokenRequest):
    new_password: str = Field(min_length=8, max_length=128)


class DeleteAccountRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class MessageResponse(BaseModel):
    message: str
    debug_token: str | None = None


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    role: UserRole
    status: UserStatus
    email_verified: bool


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse
