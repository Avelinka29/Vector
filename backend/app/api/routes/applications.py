from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.dependencies import CurrentUser, SessionDependency, StaffUser
from app.models.application import Application
from app.models.catalog import EducationInstitution, EducationSpecialty
from app.schemas.application import (
    ApplicationCreate,
    ApplicationPriorityUpdate,
    ApplicationResponse,
    ApplicationStatusUpdate,
)

router = APIRouter(prefix="/applications", tags=["applications"])


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
    institution = await session.get(EducationInstitution, payload.institution_id)
    specialty = await session.get(EducationSpecialty, payload.specialty_id)
    if institution is None or specialty is None or specialty.institution_id != institution.id:
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
