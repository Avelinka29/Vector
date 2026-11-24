"""Read-only administrator data, separate from public education catalog records."""
from typing import Literal

from fastapi import APIRouter, Query
from sqlalchemy import func, or_, select

from app.api.dependencies import AdminUser, SessionDependency
from app.models.enums import OrganizationType, UserRole, VerificationStatus
from app.models.organization import Organization
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["administration"])


@router.get('/overview')
async def overview(admin: AdminUser, session: SessionDependency):
    users = await session.scalar(select(func.count(User.id)))
    institutions = await session.scalar(select(func.count(Organization.id)).where(Organization.type == OrganizationType.INSTITUTION))
    companies = await session.scalar(select(func.count(Organization.id)).where(Organization.type == OrganizationType.EMPLOYER))
    pending = await session.scalar(select(func.count(Organization.id)).join(User, User.id == Organization.created_by_id).where(
        Organization.status.in_([VerificationStatus.PENDING, VerificationStatus.NEEDS_CLARIFICATION]),
        or_(Organization.status != VerificationStatus.PENDING, User.email_verified.is_(True)),
    ))
    return dict(users=users, institutions=institutions, companies=companies, pending=pending)


@router.get('/participants')
async def participants(admin: AdminUser, session: SessionDependency,
                       category: Literal['users', 'companies', 'universities'] = 'users',
                       search: str = Query(default='', max_length=200),
                       offset: int = Query(default=0, ge=0),
                       limit: int = Query(default=50, ge=1, le=100)):
    term = search.strip().lower()
    if category == 'users':
        query = select(User).where(User.role == UserRole.APPLICANT)
        if term:
            query = query.where(or_(func.lower(User.full_name).contains(term, autoescape=True),
                                    func.lower(User.email).contains(term, autoescape=True)))
        rows = list((await session.scalars(query.order_by(User.created_at.desc(), User.id).offset(offset).limit(limit + 1))).all())
        items = [dict(id=str(u.id), name=u.full_name or u.email, email=u.email,
                      status=u.status.value, email_verified=u.email_verified) for u in rows[:limit]]
    else:
        kind = OrganizationType.EMPLOYER if category == 'companies' else OrganizationType.INSTITUTION
        query = select(Organization, User).join(User, User.id == Organization.created_by_id).where(Organization.type == kind)
        if term:
            query = query.where(or_(func.lower(Organization.name).contains(term, autoescape=True),
                                    func.lower(User.email).contains(term, autoescape=True)))
        rows = list((await session.execute(query.order_by(Organization.created_at.desc(), Organization.id).offset(offset).limit(limit + 1))).all())
        items = [dict(id=str(o.id), name=o.name, email=u.email,
                      status=o.status.value, email_verified=u.email_verified) for o, u in rows[:limit]]
    return dict(items=items, has_more=len(rows) > limit)
