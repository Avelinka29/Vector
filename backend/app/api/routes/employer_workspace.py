from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from app.api.dependencies import CurrentUser, SessionDependency
from app.models.enums import MembershipRole, OrganizationType, VerificationStatus
from app.models.organization import Organization, OrganizationMembership
from app.models.user import User
from app.models.workspace import Vacancy, VacancyResponse
from app.schemas.workspace import (
    MemberInvite,
    MemberResponse,
    VacancyApplicationCreate,
    VacancyApplicationResponse,
    VacancyApplicationUpdate,
    VacancyCreate,
    VacancyResponse as VacancySchema,
)
from app.services.notifications import queue_notification

router = APIRouter(prefix="/employer", tags=["employer-workspace"])


async def current_employer(user: CurrentUser, session: SessionDependency) -> Organization:
    organization = await session.scalar(
        select(Organization)
        .join(OrganizationMembership, OrganizationMembership.organization_id == Organization.id)
        .where(
            OrganizationMembership.user_id == user.id,
            Organization.type == OrganizationType.EMPLOYER,
            Organization.status == VerificationStatus.ACTIVE,
        )
    )
    if organization is None:
        raise HTTPException(status_code=403, detail="Требуется активный аккаунт работодателя")
    return organization


async def vacancy_payload(vacancy: Vacancy, session: SessionDependency) -> dict:
    count = await session.scalar(
        select(func.count(VacancyResponse.id)).where(VacancyResponse.vacancy_id == vacancy.id)
    )
    return {**VacancySchema.model_validate(vacancy).model_dump(), "responses_count": count or 0}


@router.get("/vacancies", response_model=list[VacancySchema])
async def vacancies(user: CurrentUser, session: SessionDependency) -> list[dict]:
    organization = await current_employer(user, session)
    rows = list((await session.scalars(
        select(Vacancy).where(Vacancy.organization_id == organization.id).order_by(Vacancy.created_at.desc())
    )).all())
    return [await vacancy_payload(row, session) for row in rows]


@router.post("/vacancies", response_model=VacancySchema, status_code=status.HTTP_201_CREATED)
async def create_vacancy(payload: VacancyCreate, user: CurrentUser, session: SessionDependency) -> dict:
    organization = await current_employer(user, session)
    vacancy = Vacancy(organization_id=organization.id, **payload.model_dump())
    session.add(vacancy)
    await session.commit()
    await session.refresh(vacancy)
    return await vacancy_payload(vacancy, session)


@router.put("/vacancies/{vacancy_id}", response_model=VacancySchema)
async def update_vacancy(vacancy_id: UUID, payload: VacancyCreate, user: CurrentUser, session: SessionDependency) -> dict:
    organization = await current_employer(user, session)
    vacancy = await session.get(Vacancy, vacancy_id)
    if vacancy is None or vacancy.organization_id != organization.id:
        raise HTTPException(status_code=404, detail="Вакансия не найдена")
    for key, value in payload.model_dump().items():
        setattr(vacancy, key, value)
    await session.commit()
    await session.refresh(vacancy)
    return await vacancy_payload(vacancy, session)


@router.delete("/vacancies/{vacancy_id}", status_code=204)
async def delete_vacancy(vacancy_id: UUID, user: CurrentUser, session: SessionDependency) -> None:
    organization = await current_employer(user, session)
    vacancy = await session.get(Vacancy, vacancy_id)
    if vacancy is None or vacancy.organization_id != organization.id:
        raise HTTPException(status_code=404, detail="Вакансия не найдена")
    await session.delete(vacancy)
    await session.commit()


@router.get("/responses", response_model=list[VacancyApplicationResponse])
async def responses(user: CurrentUser, session: SessionDependency) -> list[dict]:
    organization = await current_employer(user, session)
    rows = (await session.execute(
        select(VacancyResponse, Vacancy, User)
        .join(Vacancy, Vacancy.id == VacancyResponse.vacancy_id)
        .join(User, User.id == VacancyResponse.applicant_id)
        .where(Vacancy.organization_id == organization.id)
        .order_by(VacancyResponse.created_at.desc())
    )).all()
    return [{
        **VacancyApplicationResponse.model_validate(response).model_dump(),
        "applicant_email": applicant.email,
        "vacancy_title": vacancy.title,
    } for response, vacancy, applicant in rows]


@router.patch("/responses/{response_id}", response_model=VacancyApplicationResponse)
async def update_response(response_id: UUID, payload: VacancyApplicationUpdate, user: CurrentUser, session: SessionDependency) -> dict:
    organization = await current_employer(user, session)
    row = await session.execute(
        select(VacancyResponse, Vacancy, User)
        .join(Vacancy, Vacancy.id == VacancyResponse.vacancy_id)
        .join(User, User.id == VacancyResponse.applicant_id)
        .where(VacancyResponse.id == response_id, Vacancy.organization_id == organization.id)
    )
    result = row.one_or_none()
    if result is None:
        raise HTTPException(status_code=404, detail="Отклик не найден")
    response, vacancy, applicant = result
    response.status = payload.status
    response.employer_comment = payload.employer_comment
    queue_notification(
        session,
        user_id=response.applicant_id,
        title="Статус отклика изменён",
        body=f"{vacancy.title}: {payload.status}",
        event_type="vacancy_response_status",
        entity_id=str(response.id),
    )
    await session.commit()
    await session.refresh(response)
    return {
        **VacancyApplicationResponse.model_validate(response).model_dump(),
        "applicant_email": applicant.email,
        "vacancy_title": vacancy.title,
    }


@router.get("/members", response_model=list[MemberResponse])
async def members(user: CurrentUser, session: SessionDependency) -> list[dict]:
    organization = await current_employer(user, session)
    rows = (await session.execute(
        select(OrganizationMembership, User)
        .join(User, User.id == OrganizationMembership.user_id)
        .where(OrganizationMembership.organization_id == organization.id)
        .order_by(OrganizationMembership.created_at)
    )).all()
    return [{
        "membership_id": membership.id,
        "user_id": member.id,
        "email": member.email,
        "role": membership.role.value,
        "created_at": membership.created_at,
    } for membership, member in rows]


@router.post("/members", response_model=MemberResponse, status_code=201)
async def invite_member(payload: MemberInvite, user: CurrentUser, session: SessionDependency) -> dict:
    organization = await current_employer(user, session)
    member = await session.scalar(select(User).where(func.lower(User.email) == payload.email.lower()))
    if member is None:
        raise HTTPException(status_code=404, detail="Сначала сотрудник должен зарегистрироваться в VECTOR")
    existing = await session.scalar(select(OrganizationMembership).where(
        OrganizationMembership.organization_id == organization.id,
        OrganizationMembership.user_id == member.id,
    ))
    if existing:
        raise HTTPException(status_code=409, detail="Сотрудник уже добавлен")
    membership = OrganizationMembership(
        organization_id=organization.id,
        user_id=member.id,
        role=MembershipRole(payload.role),
    )
    session.add(membership)
    queue_notification(
        session,
        user_id=member.id,
        title="Вас добавили в команду",
        body=organization.name,
        event_type="organization_member_added",
        entity_id=str(organization.id),
    )
    await session.commit()
    await session.refresh(membership)
    return {
        "membership_id": membership.id,
        "user_id": member.id,
        "email": member.email,
        "role": membership.role.value,
        "created_at": membership.created_at,
    }


@router.get("/public/vacancies", response_model=list[VacancySchema])
async def public_vacancies(session: SessionDependency) -> list[dict]:
    rows = list((await session.scalars(
        select(Vacancy).where(Vacancy.status == "published").order_by(Vacancy.created_at.desc())
    )).all())
    return [await vacancy_payload(row, session) for row in rows]


@router.post("/public/vacancies/{vacancy_id}/respond", response_model=VacancyApplicationResponse, status_code=201)
async def respond_to_vacancy(vacancy_id: UUID, payload: VacancyApplicationCreate, user: CurrentUser, session: SessionDependency) -> dict:
    vacancy = await session.get(Vacancy, vacancy_id)
    if vacancy is None or vacancy.status != "published":
        raise HTTPException(status_code=404, detail="Вакансия не найдена")
    response = VacancyResponse(vacancy_id=vacancy.id, applicant_id=user.id, cover_letter=payload.cover_letter)
    session.add(response)
    await session.commit()
    await session.refresh(response)
    return {
        **VacancyApplicationResponse.model_validate(response).model_dump(),
        "applicant_email": user.email,
        "vacancy_title": vacancy.title,
    }
