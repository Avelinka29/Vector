from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.dependencies import CurrentUser, SessionDependency, StaffUser
from app.services.catalog_visibility import visible_institution
from app.models.application import Application, ApplicationStatus
from app.models.catalog import (
    EducationInstitution,
    EducationInstitutionSpecialty,
    EducationSpecialty,
)
from app.schemas.application import (
    ApplicationCreate,
    ApplicationPrioritiesUpdate,
    ApplicationPriorityUpdate,
    ApplicationResponse,
    ApplicationStatusUpdate,
    OrganizationApplicationResponse,
)
from app.models.enums import OrganizationType, VerificationStatus
from app.models.organization import Organization, OrganizationMembership
from app.models.profile import ApplicantProfile
from app.models.user import User

router = APIRouter(prefix="/applications", tags=["applications"])


async def current_institution(user: CurrentUser, session: SessionDependency) -> Organization:
    organization = await session.scalar(
        select(Organization)
        .join(
            OrganizationMembership,
            OrganizationMembership.organization_id == Organization.id,
        )
        .where(
            OrganizationMembership.user_id == user.id,
            Organization.type == OrganizationType.INSTITUTION,
            Organization.status == VerificationStatus.ACTIVE,
        )
    )
    if organization is None:
        raise HTTPException(status_code=403, detail="Требуется активный аккаунт учреждения")
    return organization


@router.get("", response_model=list[ApplicationResponse])
async def my_applications(user: CurrentUser, session: SessionDependency) -> list[Application]:
    query = (
        select(Application)
        .where(Application.applicant_id == user.id)
        .order_by(Application.priority)
    )
    return list((await session.scalars(query)).all())


@router.post("", response_model=ApplicationResponse, status_code=status.HTTP_201_CREATED)
async def create_application(
    payload: ApplicationCreate, user: CurrentUser, session: SessionDependency
) -> Application:
    institution = await session.scalar(select(EducationInstitution).where(
        EducationInstitution.id == payload.institution_id, visible_institution()
    ))
    specialty = await session.get(EducationSpecialty, payload.specialty_id)
    link = await session.get(
        EducationInstitutionSpecialty,
        (payload.institution_id, payload.specialty_id),
    )
    if institution is None or specialty is None or link is None or not specialty.is_active or not link.is_active:
        raise HTTPException(status_code=400, detail="Учреждение или специальность не найдены")
    duplicate_priority = await session.scalar(
        select(Application.id).where(
            Application.applicant_id == user.id,
            Application.priority == payload.priority,
        )
    )
    if duplicate_priority:
        raise HTTPException(status_code=409, detail="Этот приоритет уже занят")
    now = datetime.now(UTC)
    history_title = "Черновик создан" if payload.status.value == "draft" else "Заявление отправлено"
    application = Application(
        id=payload.id or uuid4(),
        applicant_id=user.id,
        institution_id=institution.id,
        specialty_id=specialty.id,
        institution_name=institution.name,
        specialty_name=specialty.name,
        study_form=payload.study_form,
        funding_type=payload.funding_type,
        priority=payload.priority,
        status=payload.status,
        history=[
            {
                "id": str(uuid4()),
                "status": payload.status.value,
                "title": history_title,
                "createdAt": now.isoformat(),
            }
        ],
    )
    session.add(application)
    await session.commit()
    await session.refresh(application)
    return application


@router.get("/organization", response_model=list[OrganizationApplicationResponse])
async def organization_applications(
    user: CurrentUser,
    session: SessionDependency,
) -> list[dict]:
    organization = await current_institution(user, session)
    rows = (
        await session.execute(
            select(Application, User, ApplicantProfile)
            .join(User, User.id == Application.applicant_id)
            .outerjoin(ApplicantProfile, ApplicantProfile.user_id == Application.applicant_id)
            .where(Application.institution_name == organization.name)
            .order_by(Application.created_at.desc())
        )
    ).all()
    return [
        {
            **ApplicationResponse.model_validate(application).model_dump(),
            "applicant_email": applicant.email,
            "applicant_profile": profile.data if profile else None,
        }
        for application, applicant, profile in rows
    ]


@router.patch(
    "/organization/{application_id}/status",
    response_model=OrganizationApplicationResponse,
)
async def organization_update_status(
    application_id: UUID,
    payload: ApplicationStatusUpdate,
    user: CurrentUser,
    session: SessionDependency,
) -> dict:
    organization = await current_institution(user, session)
    application = await session.get(Application, application_id)
    if application is None or application.institution_name != organization.name:
        raise HTTPException(status_code=404, detail="Заявление не найдено")
    if payload.status not in {
        ApplicationStatus.DOCUMENTS_REVIEW,
        ApplicationStatus.ACCEPTED,
        ApplicationStatus.REJECTED,
    }:
        raise HTTPException(status_code=400, detail="Недопустимый статус заявления")
    application.status = payload.status
    application.history = [
        *application.history,
        {
            "id": str(uuid4()),
            "status": payload.status.value,
            "title": "Решение учреждения",
            "details": payload.comment,
            "createdAt": datetime.now(UTC).isoformat(),
        },
    ]
    applicant = await session.get(User, application.applicant_id)
    profile = await session.get(ApplicantProfile, application.applicant_id)
    await session.commit()
    await session.refresh(application)
    return {
        **ApplicationResponse.model_validate(application).model_dump(),
        "applicant_email": applicant.email,
        "applicant_profile": profile.data if profile else None,
    }


@router.put("/priorities", response_model=list[ApplicationResponse])
async def replace_priorities(
    payload: ApplicationPrioritiesUpdate,
    user: CurrentUser,
    session: SessionDependency,
) -> list[Application]:
    identifiers = [item.id for item in payload.applications]
    priorities = [item.priority for item in payload.applications]
    if len(set(identifiers)) != len(identifiers):
        raise HTTPException(status_code=400, detail="Заявление указано несколько раз")
    if sorted(priorities) != list(range(1, len(priorities) + 1)):
        raise HTTPException(status_code=400, detail="Приоритеты должны идти подряд от 1")

    applications = list(
        (
            await session.scalars(
                select(Application).where(
                    Application.id.in_(identifiers),
                    Application.applicant_id == user.id,
                )
            )
        ).all()
    )
    if len(applications) != len(identifiers):
        raise HTTPException(status_code=404, detail="Одно из заявлений не найдено")

    by_id = {application.id: application for application in applications}
    for item in payload.applications:
        by_id[item.id].priority = item.priority
    await session.commit()
    return sorted(applications, key=lambda application: application.priority)


@router.patch("/{application_id}/priority", response_model=ApplicationResponse)
async def update_priority(
    application_id: UUID,
    payload: ApplicationPriorityUpdate,
    user: CurrentUser,
    session: SessionDependency,
) -> Application:
    application = await session.get(Application, application_id)
    if application is None or application.applicant_id != user.id:
        raise HTTPException(status_code=404, detail="Заявление не найдено")
    application.priority = payload.priority
    await session.commit()
    await session.refresh(application)
    return application


@router.delete("/{application_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_application(
    application_id: UUID, user: CurrentUser, session: SessionDependency
) -> None:
    application = await session.get(Application, application_id)
    if application is None or application.applicant_id != user.id:
        raise HTTPException(status_code=404, detail="Заявление не найдено")
    await session.delete(application)
    await session.commit()


@router.patch("/{application_id}/status", response_model=ApplicationResponse)
async def update_status(
    application_id: UUID,
    payload: ApplicationStatusUpdate,
    staff: StaffUser,
    session: SessionDependency,
) -> Application:
    application = await session.get(Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Заявление не найдено")
    application.status = payload.status
    application.history = [
        *application.history,
        {
            "id": str(uuid4()),
            "status": payload.status.value,
            "title": "Статус изменён",
            "details": payload.comment,
            "createdAt": datetime.now(UTC).isoformat(),
        },
    ]
    await session.commit()
    await session.refresh(application)
    return application
