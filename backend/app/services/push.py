import asyncio
import logging
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionFactory
from app.models.device_token import DeviceToken
from app.models.workspace import NotificationOutbox

logger = logging.getLogger(__name__)


def _firebase_app():
    if not settings.firebase_service_account_path:
        return None
    path = Path(settings.firebase_service_account_path)
    if not path.is_file():
        return None
    import firebase_admin
    from firebase_admin import credentials

    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(credentials.Certificate(path))


async def deliver_pending_pushes() -> int:
    app = _firebase_app()
    if app is None:
        return 0
    from firebase_admin import messaging

    async with SessionFactory() as session:
        notifications = list((await session.scalars(
            select(NotificationOutbox)
            .where(NotificationOutbox.delivered_at.is_(None), NotificationOutbox.error == "")
            .order_by(NotificationOutbox.created_at)
            .limit(50)
        )).all())
        delivered = 0
        for notification in notifications:
            tokens = list((await session.scalars(
                select(DeviceToken.token).where(DeviceToken.user_id == notification.user_id)
            )).all())
            if not tokens:
                continue
            message = messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=notification.title, body=notification.body),
                data={"eventType": notification.event_type, "entityId": notification.entity_id},
            )
            try:
                response = await asyncio.to_thread(messaging.send_each_for_multicast, message, app=app)
                if response.success_count:
                    notification.delivered_at = datetime.now(UTC)
                    delivered += 1
                elif response.responses:
                    notification.error = str(response.responses[0].exception)[:1000]
            except Exception as error:
                logger.warning("Push delivery failed: %s", type(error).__name__)
        await session.commit()
        return delivered
