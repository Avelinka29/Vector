from fastapi import APIRouter, Query
from sqlalchemy import func, select

from app.api.dependencies import SessionDependency
from app.models.catalog import EducationInstitution, EducationSpecialty
from app.schemas.catalog import InstitutionResponse, SpecialtyResponse

router = APIRouter(prefix="/catalog", tags=["catalog"])


@router.get("/institutions", response_model=list[InstitutionResponse])
async def institutions(
    session: SessionDependency,
    search: str = Query(default="", max_length=200),
    institution_type: str | None = Query(default=None, alias="type"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[EducationInstitution]:
    query = select(EducationInstitution).where(EducationInstitution.is_active.is_(True))
    if search.strip():
        pattern = f"%{search.strip()}%"
        query = query.where(func.lower(EducationInstitution.name).like(func.lower(pattern)))
    if institution_type:
        query = query.where(EducationInstitution.type == institution_type)
    query = query.order_by(EducationInstitution.name).offset(offset).limit(limit)
    return list((await session.scalars(query)).all())


@router.get("/institutions/{institution_id}/specialties", response_model=list[SpecialtyResponse])
async def specialties_for_institution(
    institution_id: str,
    session: SessionDependency,
    search: str = Query(default="", max_length=200),
) -> list[EducationSpecialty]:
    query = select(EducationSpecialty).where(
        EducationSpecialty.institution_id == institution_id,
        EducationSpecialty.is_active.is_(True),
    )
    if search.strip():
        pattern = f"%{search.strip()}%"
        query = query.where(func.lower(EducationSpecialty.name).like(func.lower(pattern)))
    return list((await session.scalars(query.order_by(EducationSpecialty.name))).all())
