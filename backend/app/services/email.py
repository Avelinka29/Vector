import asyncio
import base64
from email.message import EmailMessage

import aiosmtplib
import httpx
from fastapi import HTTPException

from app.core.config import settings


async def send_action_email(email: str, subject: str, title: str, link: str) -> None:
    message = EmailMessage()
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message["Subject"] = subject
    message.set_content(f"{title}\n\n{link}\n\nЕсли это были не вы, проигнорируйте письмо.")
    try:
        async with asyncio.timeout(9):
            await deliver_message(message)
    except Exception as error:
        # Never return provider responses or credentials to the client.
        raise HTTPException(
            status_code=503,
            detail="Не удалось отправить письмо. Попробуйте позже.",
        ) from error


def mail_configured() -> bool:
    if settings.email_transport == "gmail":
        return all(
            [settings.gmail_client_id, settings.gmail_client_secret, settings.gmail_refresh_token]
        )
    return settings.email_transport == "smtp" and bool(settings.smtp_host)


async def deliver_message(message: EmailMessage) -> None:
    if not mail_configured():
        raise RuntimeError("Mail transport is not configured")
    if settings.email_transport == "gmail":
        async with httpx.AsyncClient(timeout=8) as client:
            response = await client.post(
                "https://oauth2.googleapis.com/token",
                data={
                    "client_id": settings.gmail_client_id,
                    "client_secret": settings.gmail_client_secret,
                    "refresh_token": settings.gmail_refresh_token,
                    "grant_type": "refresh_token",
                },
            )
            response.raise_for_status()
            access_token = response.json()["access_token"]
            response = await client.post(
                "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
                headers={"Authorization": f"Bearer {access_token}"},
                json={"raw": base64.urlsafe_b64encode(message.as_bytes()).decode("ascii")},
            )
            response.raise_for_status()
            if not response.json().get("id"):
                raise RuntimeError("Gmail did not acknowledge the message")
        return
    await aiosmtplib.send(
        message,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_username or None,
        password=settings.smtp_password.replace(" ", "") if settings.smtp_password else None,
        start_tls=settings.smtp_use_tls and not settings.smtp_use_ssl,
        use_tls=settings.smtp_use_ssl,
        timeout=8,
    )
