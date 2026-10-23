from fastapi import APIRouter
from sqlalchemy import select

from app.api.dependencies import CurrentUser, SessionDependency
from app.models.device_token import DeviceToken
from app.schemas.notification import DeviceTokenResponse, DeviceTokenUpsert

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
