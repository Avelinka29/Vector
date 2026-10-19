from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    new_refresh_token,
    token_digest,
    verify_password,
)
from app.models.action_token import ActionToken, ActionTokenPurpose
from app.models.enums import UserStatus
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.schemas.auth import TokenResponse, UserResponse


def normalized_email(email: str) -> str:
    return email.strip().casefold()


async def find_user_by_email(session: AsyncSession, email: str) -> User | None:
    return await session.scalar(select(User).where(User.email == normalized_email(email)))


def public_user(user: User) -> UserResponse:
    return UserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        status=user.status,
        email_verified=user.email_verified,
    )


async def issue_tokens(session: AsyncSession, user: User) -> TokenResponse:
    access_token, expires_in = create_access_token(user.id, user.role.value)
    plain_refresh_token = new_refresh_token()
    now = datetime.now(UTC)
    session.add(
        RefreshToken(
            user_id=user.id,
            digest=token_digest(plain_refresh_token),
            created_at=now,
            expires_at=now + timedelta(days=settings.refresh_token_days),
        )
    )
    await session.commit()
    return TokenResponse(
        access_token=access_token,
        refresh_token=plain_refresh_token,
        expires_in=expires_in,
        user=public_user(user),
    )


async def authenticate(session: AsyncSession, email: str, password: str) -> User:
    user = await find_user_by_email(session, email)
    if (
        user is None
        or user.password_hash is None
        or not verify_password(password, user.password_hash)
    ):
        raise HTTPException(status_code=401, detail="Неверный email или пароль")
    if user.status == UserStatus.BLOCKED:
        raise HTTPException(status_code=403, detail="Аккаунт заблокирован")
    return user


async def rotate_refresh_token(session: AsyncSession, plain_token: str) -> TokenResponse:
    stored = await session.scalar(
        select(RefreshToken).where(RefreshToken.digest == token_digest(plain_token))
    )
    now = datetime.now(UTC)
    if stored is None or stored.revoked_at is not None or stored.expires_at <= now:
        raise HTTPException(status_code=401, detail="Сессия истекла")
    user = await session.get(User, stored.user_id)
    if user is None or user.status == UserStatus.BLOCKED:
        raise HTTPException(status_code=401, detail="Сессия недействительна")
    stored.revoked_at = now
    return await issue_tokens(session, user)


async def revoke_refresh_token(session: AsyncSession, plain_token: str) -> None:
    stored = await session.scalar(
        select(RefreshToken).where(RefreshToken.digest == token_digest(plain_token))
    )
    if stored is not None and stored.revoked_at is None:
        stored.revoked_at = datetime.now(UTC)
        await session.commit()


async def create_action_token(
    session: AsyncSession,
    user: User,
    purpose: ActionTokenPurpose,
    lifetime: timedelta,
) -> str:
    plain_token = new_refresh_token()
    now = datetime.now(UTC)
    session.add(
        ActionToken(
            user_id=user.id,
            purpose=purpose,
            digest=token_digest(plain_token),
            created_at=now,
            expires_at=now + lifetime,
        )
    )
    await session.commit()
    return plain_token


async def consume_action_token(
    session: AsyncSession,
    plain_token: str,
    purpose: ActionTokenPurpose,
) -> tuple[ActionToken, User]:
    stored = await session.scalar(
        select(ActionToken).where(
            ActionToken.digest == token_digest(plain_token),
            ActionToken.purpose == purpose,
        )
    )
    now = datetime.now(UTC)
    if stored is None or stored.used_at is not None or stored.expires_at <= now:
        raise HTTPException(status_code=400, detail="Ссылка недействительна или устарела")
    user = await session.get(User, stored.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="Аккаунт не найден")
    stored.used_at = now
    return stored, user
