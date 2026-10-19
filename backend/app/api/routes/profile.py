from fastapi import APIRouter

from app.api.dependencies import CurrentUser, SessionDependency
from app.models.profile import ApplicantProfile
from app.schemas.profile import ProfileResponse, ProfileUpsert

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=ProfileResponse | None)
async def get_profile(user: CurrentUser, session: SessionDependency) -> ApplicantProfile | None:
    return await session.get(ApplicantProfile, user.id)


@router.put("", response_model=ProfileResponse)
async def save_profile(
    payload: ProfileUpsert, user: CurrentUser, session: SessionDependency
) -> ApplicantProfile:
    profile = await session.get(ApplicantProfile, user.id)
    if profile is None:
        profile = ApplicantProfile(user_id=user.id)
        session.add(profile)
    profile.schema_version = payload.schema_version
    profile.completion_percentage = payload.completion_percentage
    profile.data = payload.data
    await session.commit()
    await session.refresh(profile)
    return profile
