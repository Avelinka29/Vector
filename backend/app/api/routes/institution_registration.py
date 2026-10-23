from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select

from app.api.dependencies import CurrentUser, SessionDependency
from app.core.config import settings
from app.core.security import hash_password
from app.models.enums import MembershipRole, OrganizationType, UserRole, UserStatus, VerificationStatus
from app.models.organization import Organization, OrganizationMembership
from app.models.user import User
from app.schemas.auth import TokenResponse
from app.schemas.organization import OrganizationResponse
from app.services.auth import find_user_by_email, issue_tokens, normalized_email
from app.services.institution_email import queue_verification

router = APIRouter(prefix="/organizations", tags=["institutions-web"])


class InstitutionRegistration(BaseModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)
    contact_name: str = Field(min_length=2, max_length=200)
    name: str = Field(min_length=2, max_length=250)
    legal_name: str = Field(min_length=2, max_length=300)
    tax_id: str = Field(pattern=r"^\d{9}$")
    city: str = Field(min_length=1, max_length=120)
    address: str = Field(min_length=1, max_length=300)
    phone: str = Field(min_length=1, max_length=40)


@router.post("/register-institution", response_model=TokenResponse, status_code=201)
async def register_institution(payload: InstitutionRegistration, session: SessionDependency):
    if await find_user_by_email(session, payload.email):
        raise HTTPException(status_code=409, detail="Этот email уже зарегистрирован. Войдите в аккаунт.")
    if await session.scalar(select(Organization.id).where(Organization.tax_id == payload.tax_id)):
        raise HTTPException(status_code=409, detail="Учреждение с таким УНП уже зарегистрировано")
    user = User(email=normalized_email(payload.email), password_hash=hash_password(payload.password),
                full_name=payload.contact_name.strip(), role=UserRole.INSTITUTION,
                status=UserStatus.PENDING, email_verified=False)
    session.add(user)
    await session.flush()
    org = Organization(type=OrganizationType.INSTITUTION, name=payload.name.strip(),
                       legal_name=payload.legal_name.strip(), tax_id=payload.tax_id,
                       city=payload.city.strip(), created_by_id=user.id,
                       description=f"Адрес: {payload.address.strip()}\nТелефон: {payload.phone.strip()}",
                       status=VerificationStatus.PENDING)
    session.add(org)
    await session.flush()
    session.add(OrganizationMembership(organization_id=org.id, user_id=user.id, role=MembershipRole.OWNER))
    await queue_verification(session, user)
    # Account, membership, token and email become durable in one transaction.
    return await issue_tokens(session, user)


@router.get("/onboarding")
async def onboarding(user: CurrentUser, session: SessionDependency):
    org = await session.scalar(select(Organization).join(OrganizationMembership).where(
        OrganizationMembership.user_id == user.id
    ).limit(1))
    return {
        "email_verified": user.email_verified,
        "organization": OrganizationResponse.model_validate(org).model_dump(mode="json") if org else None,
        "email_transport_configured": bool(settings.smtp_host),
        "access_granted": bool(user.email_verified and org and org.status == VerificationStatus.ACTIVE),
    }
