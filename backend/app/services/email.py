from email.message import EmailMessage

import aiosmtplib

from app.core.config import settings


async def send_action_email(email: str, subject: str, title: str, link: str) -> None:
    if not settings.smtp_host:
        print(f"DEV EMAIL to={email} subject={subject} link={link}")
        return

    message = EmailMessage()
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message["Subject"] = subject
    message.set_content(f"{title}\n\n{link}\n\nЕсли это были не вы, проигнорируйте письмо.")
    await aiosmtplib.send(
        message,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_username,
        password=settings.smtp_password,
        start_tls=settings.smtp_use_tls,
    )
