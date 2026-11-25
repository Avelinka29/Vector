from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import or_, select

from app.api.dependencies import AdminUser, CurrentUser, SessionDependency, StaffUser
from app.models.catalog import EducationInstitution
from app.models.enums import MembershipRole, OrganizationType, UserRole, UserStatus, VerificationStatus
from app.models.institution_workspace import InstitutionProfile
from app.models.organization import Organization, OrganizationMembership
from app.models.user import User
from app.services.institution_email import queue_decision
from app.schemas.organization import (
    OrganizationCreate,
    OrganizationResponse,
    OrganizationStatusUpdate,
)

router = APIRouter(prefix="/organizations", tags=["organizations"])


def build_organization(payload: OrganizationCreate, creator_id, verified: bool) -> Organization:
    return Organization(
        type=payload.type,
        name=payload.name.strip(),
        legal_name=payload.legal_name.strip(),
        tax_id=payload.tax_id.strip(),
        city=payload.city.strip(),
        website=str(payload.website) if payload.website else "",
        description=payload.description.strip(),
        status=VerificationStatus.ACTIVE if verified else VerificationStatus.PENDING,
        created_by_id=creator_id,
    )


@router.post("/applications", response_model=OrganizationResponse, status_code=201)
async def apply_for_organization(
    payload: OrganizationCreate,
    user: CurrentUser,
    session: SessionDependency,
) -> Organization:
    if user.role not in {UserRole.APPLICANT, UserRole.EMPLOYER, UserRole.INSTITUTION}:
        raise HTTPException(status_code=403, detail="Нельзя подать заявку с этой ролью")
    existing_membership = await session.scalar(
        select(OrganizationMembership.id).where(OrganizationMembership.user_id == user.id)
    )
    if existing_membership is not None:
        raise HTTPException(status_code=409, detail="Заявка организации уже создана")
    if payload.tax_id.strip():
        existing_tax_id = await session.scalar(
            select(Organization.id).where(Organization.tax_id == payload.tax_id.strip())
        )
        if existing_tax_id is not None:
            raise HTTPException(status_code=409, detail="Организация с таким УНП уже существует")

    organization = build_organization(payload, user.id, verified=False)
    session.add(organization)
    await session.flush()
    session.add(
        OrganizationMembership(
            organization_id=organization.id,
            user_id=user.id,
            role=MembershipRole.OWNER,
        )
    )
    user.role = UserRole(payload.type.value)
    user.status = UserStatus.PENDING
    await session.commit()
    await session.refresh(organization)
    return organization


@router.get("/mine", response_model=OrganizationResponse | None)
async def my_organization(
    user: CurrentUser,
    session: SessionDependency,
) -> Organization | None:
    query = (
        select(Organization)
        .join(
            OrganizationMembership,
            OrganizationMembership.organization_id == Organization.id,
        )
        .where(OrganizationMembership.user_id == user.id)
        .order_by(Organization.created_at.desc())
        .limit(1)
    )
    return await session.scalar(query)


@router.post("/admin", response_model=OrganizationResponse, status_code=201)
async def admin_create_organization(
    payload: OrganizationCreate,
    admin: AdminUser,
    session: SessionDependency,
) -> Organization:
    organization = build_organization(payload, admin.id, verified=True)
    session.add(organization)
    await session.commit()
    await session.refresh(organization)
    return organization


@router.get("/admin", response_model=list[OrganizationResponse])
async def admin_list_organizations(
    staff: StaffUser,
    session: SessionDependency,
    verification_status: Annotated[VerificationStatus | None, Query(alias="status")] = None,
) -> list[Organization]:
    query = select(Organization).join(User, User.id == Organization.created_by_id).where(
        or_(Organization.status != VerificationStatus.PENDING, User.email_verified.is_(True))
    ).order_by(Organization.created_at.desc())
    if verification_status is not None:
        query = query.where(Organization.status == verification_status)
    return list((await session.scalars(query)).all())


@router.patch("/{organization_id}/status", response_model=OrganizationResponse)
async def update_organization_status(
    organization_id: UUID,
    payload: OrganizationStatusUpdate,
    staff: AdminUser,
    session: SessionDependency,
) -> Organization:
    organization = await session.scalar(
        select(Organization).where(Organization.id == organization_id).with_for_update()
    )
    if organization is None:
        raise HTTPException(status_code=404, detail="Организация не найдена")
    members = list((await session.scalars(select(User).join(
        OrganizationMembership, OrganizationMembership.user_id == User.id
    ).where(OrganizationMembership.organization_id == organization.id))).all())
    if payload.status == VerificationStatus.ACTIVE and any(not m.email_verified for m in members):
        raise HTTPException(status_code=409, detail="Сначала учреждение должно подтвердить email")
    previous_status = organization.status
    if (
        payload.status == VerificationStatus.ACTIVE
        and organization.type == OrganizationType.INSTITUTION
        and payload.catalog_institution_id
    ):
        catalog = await session.get(EducationInstitution, payload.catalog_institution_id)
        if catalog is None or not catalog.is_active:
            raise HTTPException(status_code=400, detail="Учреждение не найдено в справочнике")
        occupied = await session.scalar(
            select(InstitutionProfile).where(
                InstitutionProfile.catalog_institution_id == payload.catalog_institution_id,
                InstitutionProfile.organization_id != organization.id,
            )
        )
        if occupied is not None:
            raise HTTPException(status_code=409, detail="Учреждение уже связано с другой организацией")
        profile = await session.get(InstitutionProfile, organization.id)
        if profile is None:
            member = members[0]
            fields = dict(
                line.split(": ", 1)
                for line in organization.description.splitlines()
                if ": " in line
            )
            profile = InstitutionProfile(
                organization_id=organization.id,
                catalog_institution_id=payload.catalog_institution_id,
                city=organization.city,
                address=fields.get("Адрес", ""),
                phone=fields.get("Телефон", ""),
                email=member.email,
                website=organization.website,
                institution_type=(
                    catalog.type
                    if catalog.type in {"university", "academy", "institute", "college", "other"}
                    else "university"
                ),
                published=True,
            )
            session.add(profile)
        else:
            profile.catalog_institution_id = payload.catalog_institution_id
            profile.published = True
    organization.status = payload.status
    if previous_status != payload.status:
        for member in members:
            queue_decision(session, member, organization, payload.status.value)
    if payload.status == VerificationStatus.ACTIVE:
        member_ids = await session.scalars(
            select(OrganizationMembership.user_id).where(
                OrganizationMembership.organization_id == organization.id
            )
        )
        for member_id in member_ids:
            member = await session.get(User, member_id)
            if member is not None:
                member.status = UserStatus.ACTIVE
    else:
        for member in members:
            member.status = UserStatus.PENDING
    await session.commit()
    await session.refresh(organization)
    return organization
