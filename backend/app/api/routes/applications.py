from datetime import UTC, date, datetime
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
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
    ApplicationDeadlineUpdate,
    ApplicationPrioritiesUpdate,
    ApplicationPriorityUpdate,
    ApplicationResponse,
    ApplicationStatusUpdate,
    OrganizationApplicationResponse,
)
from app.core.config import settings
from app.models.enums import OrganizationType, VerificationStatus
from app.models.organization import Organization, OrganizationMembership
from app.models.institution_workspace import InstitutionProfile
from app.models.profile import ApplicantProfile
from app.models.user import User
from app.models.workspace import ApplicationComment, ApplicationDocument
from app.schemas.workspace import (
    ApplicationCommentCreate,
    ApplicationCommentResponse,
    ApplicationDocumentResponse,
)
from app.services.notifications import queue_notification

router = APIRouter(prefix="/applications", tags=["applications"])


async def accessible_application(
    application_id: UUID,
    user: CurrentUser,
    session: SessionDependency,
) -> tuple[Application, bool]:
    application = await session.get(Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Заявление не найдено")
    if application.applicant_id == user.id:
        return application, False
    if application.status == ApplicationStatus.DRAFT:
        raise HTTPException(status_code=403, detail="Черновик доступен только абитуриенту")
    organization = await session.scalar(
        select(Organization)
        .join(OrganizationMembership, OrganizationMembership.organization_id == Organization.id)
        .join(InstitutionProfile, InstitutionProfile.organization_id == Organization.id)
        .where(
            OrganizationMembership.user_id == user.id,
            Organization.type == OrganizationType.INSTITUTION,
            Organization.status == VerificationStatus.ACTIVE,
            InstitutionProfile.catalog_institution_id == application.institution_id,
        )
    )
    if organization is None:
        raise HTTPException(status_code=403, detail="Нет доступа к заявлению")
    return application, True


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
            .join(InstitutionProfile, InstitutionProfile.catalog_institution_id == Application.institution_id)
            .where(
                InstitutionProfile.organization_id == organization.id,
                Application.status != ApplicationStatus.DRAFT,
            )
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
    institution_profile = await session.get(InstitutionProfile, organization.id)
    application = await session.get(Application, application_id)
    if (
        application is None
        or institution_profile is None
        or application.institution_id != institution_profile.catalog_institution_id
        or application.status == ApplicationStatus.DRAFT
    ):
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
    queue_notification(
        session,
        user_id=application.applicant_id,
        title="Статус заявления изменён",
        body=f"{application.institution_name}: {payload.status.value}",
        event_type="application_status",
        entity_id=str(application.id),
    )
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
    for temporary_priority, application in enumerate(applications, start=1):
        application.priority = -temporary_priority
    await session.flush()
    for item in payload.applications:
        by_id[item.id].priority = item.priority
    await session.commit()
    for application in applications:
        await session.refresh(application)
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
    occupied = await session.scalar(select(Application).where(
        Application.applicant_id == user.id,
        Application.priority == payload.priority,
        Application.id != application.id,
    ))
    old_priority = application.priority
    if occupied is not None:
        occupied.priority = -1
        await session.flush()
    application.priority = payload.priority
    await session.flush()
    if occupied is not None:
        occupied.priority = old_priority
    await session.commit()
    await session.refresh(application)
    return application


@router.get("/{application_id}/documents", response_model=list[ApplicationDocumentResponse])
async def application_documents(application_id: UUID, user: CurrentUser, session: SessionDependency) -> list[ApplicationDocument]:
    await accessible_application(application_id, user, session)
    return list((await session.scalars(
        select(ApplicationDocument)
        .where(ApplicationDocument.application_id == application_id)
        .order_by(ApplicationDocument.created_at)
    )).all())


@router.post("/{application_id}/documents", response_model=ApplicationDocumentResponse, status_code=201)
async def upload_application_document(
    application_id: UUID,
    user: CurrentUser,
    session: SessionDependency,
    kind: str = Form(default="other"),
    file: UploadFile = File(...),
) -> ApplicationDocument:
    application, is_organization = await accessible_application(application_id, user, session)
    if is_organization:
        raise HTTPException(status_code=403, detail="Документы загружает абитуриент")
    content = await file.read(settings.max_upload_bytes + 1)
    if len(content) > settings.max_upload_bytes:
        raise HTTPException(status_code=413, detail="Файл превышает 10 МБ")
    allowed = {"application/pdf", "image/jpeg", "image/png", "image/heic"}
    content_type = file.content_type or "application/octet-stream"
    if content_type not in allowed:
        raise HTTPException(status_code=415, detail="Разрешены PDF, JPEG, PNG и HEIC")
    suffix = Path(file.filename or "document").suffix.lower()[:10]
    storage_key = f"{application_id}/{uuid4()}{suffix}"
    target = Path(settings.upload_directory) / storage_key
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    document = ApplicationDocument(
        application_id=application.id,
        uploaded_by_id=user.id,
        kind=kind[:80],
        original_name=(file.filename or "document")[:255],
        storage_key=storage_key,
        content_type=content_type,
        size_bytes=len(content),
    )
    session.add(document)
    await session.commit()
    await session.refresh(document)
    return document


@router.get("/{application_id}/documents/{document_id}/content")
async def download_application_document(
    application_id: UUID,
    document_id: UUID,
    user: CurrentUser,
    session: SessionDependency,
) -> FileResponse:
    await accessible_application(application_id, user, session)
    document = await session.get(ApplicationDocument, document_id)
    if document is None or document.application_id != application_id:
        raise HTTPException(status_code=404, detail="Документ не найден")
    target = Path(settings.upload_directory) / document.storage_key
    if not target.is_file():
        raise HTTPException(status_code=404, detail="Файл документа не найден")
    return FileResponse(target, media_type=document.content_type, filename=document.original_name)


@router.delete("/{application_id}/documents/{document_id}", status_code=204)
async def delete_application_document(
    application_id: UUID,
    document_id: UUID,
    user: CurrentUser,
    session: SessionDependency,
) -> None:
    application, is_organization = await accessible_application(application_id, user, session)
    document = await session.get(ApplicationDocument, document_id)
    if document is None or document.application_id != application.id:
        raise HTTPException(status_code=404, detail="Документ не найден")
    if is_organization or document.uploaded_by_id != user.id:
        raise HTTPException(status_code=403, detail="Удалить документ может только автор")
    target = Path(settings.upload_directory) / document.storage_key
    target.unlink(missing_ok=True)
    await session.delete(document)
    await session.commit()


@router.get("/{application_id}/comments", response_model=list[ApplicationCommentResponse])
async def application_comments(application_id: UUID, user: CurrentUser, session: SessionDependency) -> list[ApplicationComment]:
    _, is_organization = await accessible_application(application_id, user, session)
    query = select(ApplicationComment).where(ApplicationComment.application_id == application_id)
    if not is_organization:
        query = query.where(ApplicationComment.is_internal.is_(False))
    return list((await session.scalars(query.order_by(ApplicationComment.created_at))).all())


@router.post("/{application_id}/comments", response_model=ApplicationCommentResponse, status_code=201)
async def add_application_comment(
    application_id: UUID,
    payload: ApplicationCommentCreate,
    user: CurrentUser,
    session: SessionDependency,
) -> ApplicationComment:
    application, is_organization = await accessible_application(application_id, user, session)
    if payload.is_internal and not is_organization:
        raise HTTPException(status_code=403, detail="Внутренние комментарии доступны учреждению")
    comment = ApplicationComment(
        application_id=application.id,
        author_id=user.id,
        text=payload.text,
        is_internal=payload.is_internal,
    )
    session.add(comment)
    if is_organization and not payload.is_internal:
        queue_notification(
            session,
            user_id=application.applicant_id,
            title="Новый комментарий к заявлению",
            body=payload.text[:180],
            event_type="application_comment",
            entity_id=str(application.id),
        )
    await session.commit()
    await session.refresh(comment)
    return comment


@router.patch("/{application_id}/deadline", response_model=ApplicationResponse)
async def update_application_deadline(
    application_id: UUID,
    payload: ApplicationDeadlineUpdate,
    user: CurrentUser,
    session: SessionDependency,
) -> Application:
    application, is_organization = await accessible_application(application_id, user, session)
    if not is_organization:
        raise HTTPException(status_code=403, detail="Срок устанавливает учреждение")
    if payload.submission_deadline is not None and payload.submission_deadline < date.today():
        raise HTTPException(status_code=400, detail="Срок не может быть в прошлом")
    application.submission_deadline = payload.submission_deadline
    queue_notification(
        session,
        user_id=application.applicant_id,
        title="Установлен срок по заявлению",
        body=str(payload.submission_deadline or "Срок снят"),
        event_type="application_deadline",
        entity_id=str(application.id),
    )
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
