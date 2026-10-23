from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.database import Base
from app.models.email_outbox import EmailOutbox
from app.services import institution_email


async def test_delivery_failure_keeps_message_for_retry(tmp_path, monkeypatch):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'mail.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as c:
        await c.run_sync(lambda sync: Base.metadata.create_all(sync, tables=[EmailOutbox.__table__]))
    monkeypatch.setattr(institution_email, 'SessionFactory', factory)
    monkeypatch.setattr(institution_email.settings, 'smtp_host', 'smtp.test.invalid')
    async with factory() as session:
        session.add(EmailOutbox(recipient='test@example.com', subject='Test', body='Test'))
        await session.commit()
    async def fail(*args, **kwargs):
        raise ConnectionError('Synthetic SMTP failure')
    monkeypatch.setattr(institution_email.aiosmtplib, 'send', fail)
    await institution_email.deliver_pending()
    async with factory() as session:
        mail = (await session.scalars(select(EmailOutbox))).one()
        assert mail.attempts == 1 and mail.sent_at is None
        assert mail.next_attempt_at is not None
        assert mail.last_error == 'ConnectionError'
        mail.next_attempt_at = None
        await session.commit()
    async def succeed(*args, **kwargs):
        return {}, 'Synthetic SMTP accepted'
    monkeypatch.setattr(institution_email.aiosmtplib, 'send', succeed)
    await institution_email.deliver_pending()
    async with factory() as session:
        mail = (await session.scalars(select(EmailOutbox))).one()
        assert mail.attempts == 2 and mail.sent_at is not None
    await engine.dispose()
