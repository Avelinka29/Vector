from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workspace import NotificationOutbox


def queue_notification(
    session: AsyncSession,
    *,
    user_id: UUID,
    title: str,
    body: str,
    event_type: str,
    entity_id: str = "",
) -> NotificationOutbox:
    notification = NotificationOutbox(
        user_id=user_id,
        title=title,
        body=body,
        event_type=event_type,
        entity_id=entity_id,
    )
    session.add(notification)
    return notification
