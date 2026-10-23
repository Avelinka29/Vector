import re

from fastapi import APIRouter
from sqlalchemy import or_, select

from app.api.dependencies import CurrentUser, SessionDependency
from app.models.catalog import EducationInstitution, EducationSpecialty
from app.schemas.assistant import AssistantMessage, AssistantReply

router = APIRouter(prefix="/assistant", tags=["assistant"])


@router.post("/chat", response_model=AssistantReply)
async def chat(
    payload: AssistantMessage,
    user: CurrentUser,
    session: SessionDependency,
) -> AssistantReply:
    del user
    words = [word for word in re.findall(r"[\w-]+", payload.message.lower()) if len(word) >= 3]
    if not words:
        return AssistantReply(
            answer="Уточните название учреждения, специальности или города — я поищу в справочнике.",
        )

    patterns = [f"%{word}%" for word in words[:6]]
    institution_filters = []
    specialty_filters = []
    for pattern in patterns:
        institution_filters.extend(
            [
                EducationInstitution.name.ilike(pattern),
                EducationInstitution.locality.ilike(pattern),
                EducationInstitution.region_id.ilike(pattern),
            ]
        )
        specialty_filters.extend(
            [
                EducationSpecialty.name.ilike(pattern),
                EducationSpecialty.code.ilike(pattern),
            ]
        )

    institutions = list(
        (await session.scalars(select(EducationInstitution).where(or_(*institution_filters)).limit(5))).all()
    )
    specialties = list(
        (await session.scalars(select(EducationSpecialty).where(or_(*specialty_filters)).limit(5))).all()
    )

    sections: list[str] = []
    if institutions:
        sections.append("Учреждения: " + "; ".join(item.name for item in institutions))
    if specialties:
        sections.append("Специальности: " + "; ".join(item.name for item in specialties))
    if not sections:
        sections.append(
            "В текущем справочнике совпадений нет. Попробуйте написать город, полное название или направление обучения."
        )
    sections.append("Данные справочника могут требовать проверки по официальному источнику.")
    return AssistantReply(
        answer="\n\n".join(sections),
        institution_ids=[item.id for item in institutions],
        specialty_ids=[item.id for item in specialties],
    )
