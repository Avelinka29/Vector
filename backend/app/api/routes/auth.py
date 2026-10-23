from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import update

from app.api.dependencies import CurrentUser, SessionDependency
from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.models.action_token import ActionTokenPurpose
from app.models.enums import UserRole, UserStatus
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.schemas.auth import (
    ActionTokenRequest,
    DeleteAccountRequest,
    EmailRequest,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    PasswordResetConfirmRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)
from app.services.auth import (
    authenticate,
    consume_action_token,
    create_action_token,
    find_user_by_email,
    issue_tokens,
    normalized_email,
    public_user,
    revoke_refresh_token,
    rotate_refresh_token,
)
from app.services.email import send_action_email

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, session: SessionDependency) -> TokenResponse:
    if await find_user_by_email(session, payload.email):
        raise HTTPException(status_code=409, detail="Аккаунт с таким email уже существует")
    if payload.role not in {
        UserRole.APPLICANT,
        UserRole.EMPLOYER,
        UserRole.INSTITUTION,
    }:
        raise HTTPException(status_code=400, detail="Недопустимая роль для регистрации")
    user = User(
        email=normalized_email(payload.email),
        password_hash=hash_password(payload.password),
        full_name=payload.full_name.strip(),
        role=payload.role,
        status=(
            UserStatus.ACTIVE
            if payload.role == UserRole.APPLICANT
            else UserStatus.PENDING
        ),
    )
    session.add(user)
    await session.flush()
    response = await issue_tokens(session, user)
    token = await create_action_token(
        session, user, ActionTokenPurpose.VERIFY_EMAIL, timedelta(hours=24)
    )
    await send_action_email(
        user.email,
        "Подтверждение email VECTOR",
        "Подтвердите адрес электронной почты",
        action_link("verify-email", token),
    )
    return response


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, session: SessionDependency) -> TokenResponse:
    return await issue_tokens(session, await authenticate(session, payload.email, payload.password))


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshRequest, session: SessionDependency) -> TokenResponse:
    return await rotate_refresh_token(session, payload.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: LogoutRequest, session: SessionDependency) -> None:
    await revoke_refresh_token(session, payload.refresh_token)


@router.get("/me", response_model=UserResponse)
async def me(user: CurrentUser) -> UserResponse:
    return public_user(user)


def action_link(action: str, token: str) -> str:
    return f"{settings.public_app_url}/{action}?token={token}"


def development_token(token: str) -> str | None:
    return token if settings.environment == "development" else None


@router.post("/email/verification/request", response_model=MessageResponse)
async def request_email_verification(
    user: CurrentUser, session: SessionDependency
) -> MessageResponse:
    if user.email_verified:
        return MessageResponse(message="Email уже подтверждён")
    if user.role == UserRole.INSTITUTION:
        from app.services.institution_email import queue_verification
        await queue_verification(session, user)
        await session.commit()
        return MessageResponse(message="Письмо поставлено в очередь отправки")
    token = await create_action_token(
        session, user, ActionTokenPurpose.VERIFY_EMAIL, timedelta(hours=24)
    )
    await send_action_email(
        user.email,
        "Подтверждение email VECTOR",
        "Подтвердите адрес электронной почты",
        action_link("verify-email", token),
    )
    return MessageResponse(message="Письмо отправлено", debug_token=development_token(token))


@router.post("/email/verification/confirm", response_model=MessageResponse)
async def confirm_email(payload: ActionTokenRequest, session: SessionDependency) -> MessageResponse:
    _, user = await consume_action_token(session, payload.token, ActionTokenPurpose.VERIFY_EMAIL)
    user.email_verified = True
    await session.commit()
    return MessageResponse(message="Email подтверждён")


@router.post("/password/reset/request", response_model=MessageResponse)
async def request_password_reset(
    payload: EmailRequest, session: SessionDependency
) -> MessageResponse:
    user = await find_user_by_email(session, payload.email)
    debug_token = None
    if user is not None:
        token = await create_action_token(
            session, user, ActionTokenPurpose.RESET_PASSWORD, timedelta(minutes=30)
        )
        await send_action_email(
            user.email,
            "Восстановление пароля VECTOR",
            "Установите новый пароль",
            action_link("reset-password", token),
        )
        debug_token = development_token(token)
    return MessageResponse(
        message="Если аккаунт существует, письмо отправлено", debug_token=debug_token
    )


@router.post("/password/reset/confirm", response_model=MessageResponse)
async def confirm_password_reset(
    payload: PasswordResetConfirmRequest, session: SessionDependency
) -> MessageResponse:
    _, user = await consume_action_token(session, payload.token, ActionTokenPurpose.RESET_PASSWORD)
    user.password_hash = hash_password(payload.new_password)
    await session.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=datetime.now(UTC))
    )
    await session.commit()
    return MessageResponse(message="Пароль изменён. Войдите заново")


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    payload: DeleteAccountRequest, user: CurrentUser, session: SessionDependency
) -> None:
    if user.password_hash is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверный пароль")
    await session.delete(user)
    await session.commit()
