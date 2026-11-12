from fastapi import APIRouter, Query
from sqlalchemy import func, select

from app.api.dependencies import SessionDependency
from app.models.catalog import EducationInstitution, EducationInstitutionSpecialty, EducationPassingScore, EducationSpecialty
from app.models.institution_workspace import InstitutionProfile, InstitutionProgram
from app.schemas.catalog import InstitutionResponse, PassingScoreResponse, SpecialtyResponse
from app.services.catalog_visibility import visible_institution
from app.services.catalog_search import institution_search

router = APIRouter(prefix="/catalog", tags=["catalog"])


@router.get("/institutions/{institution_id}/passing-scores", response_model=list[PassingScoreResponse])
async def passing_scores_for_institution(
    institution_id: str,
    session: SessionDependency,
    year: int | None = Query(default=None, ge=2000, le=2100),
):
    query = select(EducationPassingScore).join(
        EducationInstitution, EducationInstitution.id == EducationPassingScore.institution_id
    ).join(EducationInstitutionSpecialty,
           (EducationInstitutionSpecialty.institution_id == EducationPassingScore.institution_id)
           & (EducationInstitutionSpecialty.specialty_id == EducationPassingScore.specialty_id)
    ).join(EducationSpecialty, EducationSpecialty.id == EducationPassingScore.specialty_id).where(
        EducationPassingScore.institution_id == institution_id, visible_institution(),
        EducationInstitutionSpecialty.is_active.is_(True), EducationSpecialty.is_active.is_(True))
    if year is not None:
        query = query.where(EducationPassingScore.admission_year == year)
    return list((await session.scalars(query.order_by(EducationPassingScore.admission_year.desc(), EducationPassingScore.specialty_id))).all())


@router.get("/institutions", response_model=list[InstitutionResponse])
async def institutions(
    session: SessionDependency,
    search: str = Query(default="", max_length=200),
    institution_type: str | None = Query(default=None, alias="type"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    query = select(EducationInstitution, InstitutionProfile.description).outerjoin(
        InstitutionProfile, InstitutionProfile.catalog_institution_id == EducationInstitution.id
    ).where(visible_institution())
    if search.strip():
        query = query.where(institution_search(search.strip()))
    if institution_type:
        query = query.where(EducationInstitution.type == institution_type)
    rows = (await session.execute(query.order_by(EducationInstitution.name, EducationInstitution.id).offset(offset).limit(limit))).all()
    levels = {}
    if rows:
        level_rows = (await session.execute(select(EducationInstitutionSpecialty.institution_id, EducationSpecialty.education_level).join(
            EducationSpecialty, EducationSpecialty.id == EducationInstitutionSpecialty.specialty_id
        ).where(EducationInstitutionSpecialty.institution_id.in_([record.id for record, _ in rows]),
                EducationInstitutionSpecialty.is_active.is_(True), EducationSpecialty.is_active.is_(True)))).all()
        for institution_id, level in level_rows:
            if level:
                levels.setdefault(institution_id, set()).add(level)
    return [InstitutionResponse.model_validate(record).model_copy(update={"description": description or "", "education_levels": sorted(levels.get(record.id, []))}) for record, description in rows]


def specialty_query():
    return select(EducationSpecialty, EducationInstitutionSpecialty, InstitutionProgram).join(
        EducationInstitutionSpecialty, EducationInstitutionSpecialty.specialty_id == EducationSpecialty.id
    ).join(EducationInstitution, EducationInstitution.id == EducationInstitutionSpecialty.institution_id).outerjoin(
        InstitutionProgram, InstitutionProgram.specialty_id == EducationSpecialty.id
    ).where(visible_institution(), EducationSpecialty.is_active.is_(True),
            EducationInstitutionSpecialty.is_active.is_(True))


def specialty_response(rows):
    return [SpecialtyResponse(
        id=specialty.id, institution_id=link.institution_id, name=specialty.name, code=specialty.code,
        education_level=specialty.education_level, qualification=link.qualification or specialty.qualification,
        study_forms=specialty.study_forms, source_url=link.source_url or specialty.source_url,
        last_verified_at=specialty.last_verified_at,
        needs_verification=link.needs_verification or specialty.needs_verification,
        faculty=program.faculty if program else "", duration=program.duration if program else None,
        budget_places=program.budget_places if program else None,
        paid_places=program.paid_places if program else None,
        description=program.description if program else "",
    ) for specialty, link, program in rows]


@router.get("/specialties", response_model=list[SpecialtyResponse])
async def published_specialties(session: SessionDependency,
                                limit: int = Query(default=200, ge=1, le=200),
                                offset: int = Query(default=0, ge=0)):
    rows = (await session.execute(specialty_query().order_by(
        EducationSpecialty.id, EducationInstitutionSpecialty.institution_id
    ).offset(offset).limit(limit))).all()
    return specialty_response(rows)


@router.get("/institutions/{institution_id}/specialties", response_model=list[SpecialtyResponse])
async def specialties_for_institution(institution_id: str, session: SessionDependency,
                                      search: str = Query(default="", max_length=200)):
    query = specialty_query().where(EducationInstitutionSpecialty.institution_id == institution_id)
    if search.strip():
        query = query.where(func.lower(EducationSpecialty.name).like(func.lower(f"%{search.strip()}%")))
    return specialty_response((await session.execute(query.order_by(EducationSpecialty.name, EducationSpecialty.id))).all())
