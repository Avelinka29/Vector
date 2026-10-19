from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from app.api.dependencies import AdminUser, CurrentUser, SessionDependency, StaffUser
from app.models.enums import MembershipRole, UserRole, UserStatus, VerificationStatus
from app.models.organization import Organization, OrganizationMembership
from app.models.user import User
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
    query = select(Organization).order_by(Organization.created_at.desc())
    if verification_status is not None:
        query = query.where(Organization.status == verification_status)
    return list((await session.scalars(query)).all())


@router.patch("/{organization_id}/status", response_model=OrganizationResponse)
async def update_organization_status(
    organization_id: UUID,
    payload: OrganizationStatusUpdate,
    staff: StaffUser,
    session: SessionDependency,
) -> Organization:
    organization = await session.get(Organization, organization_id)
    if organization is None:
        raise HTTPException(status_code=404, detail="Организация не найдена")
    organization.status = payload.status
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
    await session.commit()
    await session.refresh(organization)
    return organization
