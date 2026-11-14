from uuid import UUID

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from app.api.dependencies import CurrentUser, SessionDependency
from app.models.device_token import DeviceToken
from app.schemas.notification import DeviceTokenResponse, DeviceTokenUpsert
from app.models.workspace import NotificationOutbox
from app.schemas.notification_event import NotificationResponse

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.put("/device-token", response_model=DeviceTokenResponse)
async def upsert_device_token(
    payload: DeviceTokenUpsert,
    user: CurrentUser,
    session: SessionDependency,
) -> DeviceToken:
    device_token = await session.scalar(select(DeviceToken).where(DeviceToken.token == payload.token))
    if device_token is None:
        device_token = DeviceToken(
            user_id=user.id,
            token=payload.token,
            platform=payload.platform,
        )
        session.add(device_token)
    else:
        device_token.user_id = user.id
        device_token.platform = payload.platform
    await session.commit()
    await session.refresh(device_token)
    return device_token


@router.get("", response_model=list[NotificationResponse])
async def my_notifications(user: CurrentUser, session: SessionDependency) -> list[NotificationOutbox]:
    return list((await session.scalars(
        select(NotificationOutbox)
        .where(NotificationOutbox.user_id == user.id)
        .order_by(NotificationOutbox.created_at.desc())
        .limit(100)
    )).all())


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_read(notification_id: UUID, user: CurrentUser, session: SessionDependency) -> NotificationOutbox:
    notification = await session.get(NotificationOutbox, notification_id)
    if notification is None or notification.user_id != user.id:
        raise HTTPException(status_code=404, detail="Уведомление не найдено")
    notification.is_read = True
    await session.commit()
    await session.refresh(notification)
    return notification


@router.post("/read-all", status_code=204)
async def mark_all_read(user: CurrentUser, session: SessionDependency) -> None:
    rows = list((await session.scalars(
        select(NotificationOutbox).where(
            NotificationOutbox.user_id == user.id,
            NotificationOutbox.is_read.is_(False),
        )
    )).all())
    for row in rows:
        row.is_read = True
    await session.commit()
