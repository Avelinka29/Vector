from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.dependencies import CurrentUser, SessionDependency
from app.models.catalog import EducationInstitution, EducationInstitutionSpecialty, EducationSpecialty
from app.models.enums import MembershipRole, OrganizationType, UserRole, UserStatus, VerificationStatus
from app.models.institution_workspace import InstitutionProfile, InstitutionProgram
from app.models.organization import Organization, OrganizationMembership
from app.schemas.institution_workspace import InstitutionProfileUpdate, InstitutionProgramUpdate

router = APIRouter(prefix="/institutions/workspace", tags=["institution-workspace"])


async def approved_institution(user: CurrentUser, session: SessionDependency):
    if user.role != UserRole.INSTITUTION or not user.email_verified or user.status != UserStatus.ACTIVE:
        raise HTTPException(status_code=403, detail="Подтвердите email и дождитесь одобрения учреждения")
    row = (await session.execute(select(Organization, OrganizationMembership).join(
        OrganizationMembership, OrganizationMembership.organization_id == Organization.id
    ).where(OrganizationMembership.user_id == user.id).with_for_update())).first()
    if row is None or row[0].type != OrganizationType.INSTITUTION or row[0].status != VerificationStatus.ACTIVE:
        raise HTTPException(status_code=403, detail="Учреждение не подтверждено")
    return row


InstitutionAccess = Annotated[tuple, Depends(approved_institution)]


def require_editor(access):
    if access[1].role not in {MembershipRole.OWNER, MembershipRole.MANAGER}:
        raise HTTPException(status_code=403, detail="Нет прав на изменение профиля учреждения")


async def profile_for(session, org, user):
    profile = await session.get(InstitutionProfile, org.id)
    if profile:
        return profile
    catalog_id = "organization-" + org.id.hex
    # Never match by name and never take ownership of an imported catalog entry.
    catalog = EducationInstitution(id=catalog_id, name=org.name, is_active=False,
                                   identity_status="organization_confirmed", needs_verification=True)
    session.add(catalog)
    await session.flush()
    old_fields = dict(line.split(": ", 1) for line in org.description.splitlines() if ": " in line)
    profile = InstitutionProfile(organization_id=org.id, catalog_institution_id=catalog_id,
                                 city=org.city, address=old_fields.get("Адрес", ""),
                                 phone=old_fields.get("Телефон", ""), email=user.email,
                                 website=org.website, published=False, revision=0,
                                 institution_type="university", region_id="", admissions_url="",
                                 description="")
    session.add(profile)
    await session.flush()
    return profile


def profile_json(profile, org):
    return {"organization_id": str(org.id), "catalog_institution_id": profile.catalog_institution_id,
            "name": org.name, "legal_name": org.legal_name, "tax_id": org.tax_id,
            **{k: getattr(profile, k) for k in ["city", "region_id", "address", "website", "phone", "email", "admissions_url", "description", "institution_type", "published", "revision"]}}


def program_json(program):
    return {"id": str(program.id), "specialty_id": program.specialty_id,
            **{k: getattr(program, k) for k in ["name", "code", "faculty", "education_level", "qualification", "study_form", "duration", "budget_places", "paid_places", "description", "status", "revision"]}}


async def synchronize_profile(session, profile, org):
    catalog = await session.get(EducationInstitution, profile.catalog_institution_id)
    for key, value in {
        "name": org.name, "type": profile.institution_type, "locality": profile.city,
        "region_id": profile.region_id, "address": profile.address, "website_url": profile.website,
        "admissions_phone": profile.phone, "admissions_email": profile.email,
        "admissions_url": profile.admissions_url, "source_url": profile.website,
        "is_active": profile.published,
    }.items():
        setattr(catalog, key, value)


@router.get("")
async def workspace(access: InstitutionAccess, user: CurrentUser, session: SessionDependency):
    org = access[0]
    profile = await profile_for(session, org, user)
    programs = list((await session.scalars(select(InstitutionProgram).where(
        InstitutionProgram.organization_id == org.id
    ).order_by(InstitutionProgram.name))).all())
    await session.commit()
    return {"profile": profile_json(profile, org), "programs": [program_json(p) for p in programs]}


@router.put("/profile")
async def update_profile(payload: InstitutionProfileUpdate, access: InstitutionAccess,
                         user: CurrentUser, session: SessionDependency):
    require_editor(access)
    org = access[0]
    profile = await profile_for(session, org, user)
    if profile.revision != payload.revision:
        raise HTTPException(status_code=409, detail="Профиль уже изменён. Обновите страницу перед сохранением.")
    for key, value in payload.model_dump(exclude={"revision"}).items():
        if key in {"website", "admissions_url"}:
            value = str(value) if value else ""
        setattr(profile, key, value)
    profile.revision += 1
    org.city, org.website = profile.city, profile.website
    await synchronize_profile(session, profile, org)
    await session.commit()
    return profile_json(profile, org)


async def save_program(payload, access, user, session, program_id=None):
    require_editor(access)
    org = access[0]
    profile = await profile_for(session, org, user)
    program = await session.get(InstitutionProgram, program_id) if program_id else None
    if program_id and (program is None or program.organization_id != org.id):
        raise HTTPException(status_code=404, detail="Программа не найдена")
    if program and program.revision != payload.revision:
        raise HTTPException(status_code=409, detail="Программа уже изменена. Обновите страницу перед сохранением.")
    if not program and payload.revision != 0:
        raise HTTPException(status_code=409, detail="Некорректная версия новой программы")
    if not program:
        identifier = uuid4()
        specialty = EducationSpecialty(id="program-" + identifier.hex, name=payload.name, is_active=False)
        session.add(specialty)
        await session.flush()
        program = InstitutionProgram(id=identifier, organization_id=org.id,
                                     specialty_id=specialty.id, revision=0)
        session.add(program)
    else:
        specialty = await session.get(EducationSpecialty, program.specialty_id)
    for key, value in payload.model_dump(exclude={"revision"}).items():
        setattr(program, key, value)
    program.revision += 1
    specialty.name, specialty.code = program.name, program.code
    specialty.education_level, specialty.qualification = program.education_level, program.qualification
    specialty.study_forms = [{"full_time": "Очная", "part_time": "Заочная", "distance": "Дистанционная"}[program.study_form]]
    specialty.is_active = program.status == "published"
    with session.no_autoflush:
        link = await session.get(EducationInstitutionSpecialty, (profile.catalog_institution_id, specialty.id))
    if not link:
        link = EducationInstitutionSpecialty(institution_id=profile.catalog_institution_id, specialty_id=specialty.id)
        session.add(link)
    link.qualification = program.qualification
    link.is_active = specialty.is_active
    link.source_label = "Данные предоставлены учреждением"
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(status_code=409, detail="Программа с таким кодом и формой обучения уже есть") from error
    return program_json(program)


@router.post("/programs", status_code=201)
async def create_program(payload: InstitutionProgramUpdate, access: InstitutionAccess,
                         user: CurrentUser, session: SessionDependency):
    return await save_program(payload, access, user, session)


@router.put("/programs/{program_id}")
async def update_program(program_id: UUID, payload: InstitutionProgramUpdate,
                         access: InstitutionAccess, user: CurrentUser, session: SessionDependency):
    return await save_program(payload, access, user, session, program_id)
