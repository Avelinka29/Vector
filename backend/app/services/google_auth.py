import asyncio

from fastapi import HTTPException
from google.auth.exceptions import GoogleAuthError, InvalidValue, MalformedError
from google.auth.transport.requests import Request
from google.oauth2 import id_token
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.config import settings
from app.models.enums import UserRole, UserStatus
from app.models.user import User
from app.services.auth import find_user_by_email, issue_tokens, normalized_email


def verify_google_token(token: str) -> dict:
    if not settings.google_client_id:
        raise HTTPException(status_code=503, detail="Вход через Google пока не настроен")
    try:
        claims = id_token.verify_oauth2_token(token, Request(), settings.google_client_id)
    except (ValueError, InvalidValue, MalformedError) as error:
        raise HTTPException(status_code=401, detail="Недействительный токен Google") from error
    except GoogleAuthError as error:
        raise HTTPException(status_code=503, detail="Google временно недоступен") from error
    if not claims.get("sub") or not claims.get("email") or claims.get("email_verified") is not True:
        raise HTTPException(status_code=401, detail="Google не подтвердил email")
    return claims


async def google_login(session, token: str, role: UserRole, register: bool = False):
    if role not in {UserRole.APPLICANT, UserRole.EMPLOYER, UserRole.INSTITUTION}:
        raise HTTPException(status_code=400, detail="Недопустимая роль для регистрации")
    claims = await asyncio.to_thread(verify_google_token, token)
    user = await session.scalar(select(User).where(User.google_subject == claims["sub"]))
    if register:
        email = normalized_email(claims["email"])
        if user is not None or await find_user_by_email(session, email) is not None:
            raise HTTPException(status_code=409, detail="Аккаунт уже существует. Войдите в него; Google можно привязать в настройках аккаунта.")
        user = User(
            email=email,
            full_name=str(claims.get("name") or email.split("@")[0])[:200],
            role=role,
            status=UserStatus.ACTIVE if role == UserRole.APPLICANT else UserStatus.PENDING,
            google_subject=claims["sub"],
            email_verified=True,
        )
        session.add(user)
    elif user is None:
        raise HTTPException(status_code=409, detail="Google не привязан к аккаунту. Войдите с паролем и привяжите Google в настройках или выберите регистрацию.")
    if user.status == UserStatus.BLOCKED:
        raise HTTPException(status_code=403, detail="Аккаунт заблокирован")
    try:
        await session.flush()
        return await issue_tokens(session, user)
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(status_code=409, detail="Аккаунт уже изменён. Повторите вход.") from error


async def link_google(session, user, token: str):
    claims = await asyncio.to_thread(verify_google_token, token)
    if normalized_email(claims["email"]) != normalized_email(user.email):
        raise HTTPException(status_code=409, detail="Выберите Google с тем же email, что у аккаунта VECTOR.")
    if user.google_subject is not None and user.google_subject != claims["sub"]:
        raise HTTPException(status_code=409, detail="К аккаунту уже привязан другой Google.")
    owner = await session.scalar(select(User).where(User.google_subject == claims["sub"]))
    if owner is not None and owner.id != user.id:
        raise HTTPException(status_code=409, detail="Google уже привязан к другому аккаунту.")
    user.google_subject = claims["sub"]
    user.email_verified = True
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(status_code=409, detail="Google уже привязан к другому аккаунту.") from error
