from datetime import UTC, datetime, timedelta
from email.message import EmailMessage

import aiosmtplib
from sqlalchemy import or_, select

from app.core.config import settings
from app.core.database import SessionFactory
from app.models.action_token import ActionTokenPurpose
from app.models.email_outbox import EmailOutbox
from app.services.auth import create_action_token


async def queue_verification(session, user) -> None:
    token = await create_action_token(
        session, user, ActionTokenPurpose.VERIFY_EMAIL, timedelta(hours=24), commit=False
    )
    link = f"{settings.web_app_url.rstrip('/')}/#verify-email?token={token}"
    session.add(EmailOutbox(
        recipient=user.email,
        subject="Подтвердите email учреждения — VECTOR",
        body=("Подтвердите рабочий email учреждения по ссылке:\n\n"
              f"{link}\n\nСсылка действует 24 часа. После подтверждения заявку "
              "рассмотрит администратор VECTOR в мобильном приложении. "
              "Если это были не вы, проигнорируйте письмо."),
    ))


def queue_decision(session, user, organization, status) -> None:
    labels = {
        "active": ("Учреждение подтверждено — VECTOR", "Ваше учреждение подтверждено. Доступ к кабинету открыт."),
        "needs_clarification": ("Нужно уточнение — VECTOR", "Администратор запросил уточнение сведений учреждения."),
        "rejected": ("Решение по заявке — VECTOR", "Заявка учреждения не подтверждена. Обратитесь к администратору."),
    }
    if status not in labels:
        return
    subject, text = labels[status]
    session.add(EmailOutbox(
        recipient=user.email,
        subject=subject,
        body=f"{organization.name}\n\n{text}\n\n{settings.web_app_url.rstrip('/')}/#login",
    ))


async def deliver_pending() -> None:
    if not settings.smtp_host:
        return  # Keep queued; never claim delivery without a configured transport.
    async with SessionFactory() as session:
        now = datetime.now(UTC)
        items = await session.scalars(
            select(EmailOutbox).where(
                EmailOutbox.sent_at.is_(None),
                or_(EmailOutbox.next_attempt_at.is_(None), EmailOutbox.next_attempt_at <= now),
            ).order_by(EmailOutbox.created_at).limit(10).with_for_update(skip_locked=True)
        )
        for item in items:
            item.attempts += 1
            message = EmailMessage()
            message["From"] = settings.smtp_from_email
            message["To"] = item.recipient
            message["Subject"] = item.subject
            message.set_content(item.body)
            try:
                await aiosmtplib.send(
                    message, hostname=settings.smtp_host, port=settings.smtp_port,
                    username=settings.smtp_username or None, password=settings.smtp_password or None,
                    start_tls=settings.smtp_use_tls, timeout=15,
                )
                item.sent_at = datetime.now(UTC)
                item.last_error = ""
            except Exception as error:
                item.last_error = type(error).__name__  # No addresses, tokens or SMTP secrets in logs.
                item.next_attempt_at = now + timedelta(seconds=min(3600, 30 * 2 ** min(item.attempts, 7)))
        await session.commit()
