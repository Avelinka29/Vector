import asyncio
import re
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter
from sqlalchemy import delete, func, or_, select

from app.api.dependencies import CurrentUser, SessionDependency
from app.core.config import settings
from app.models.catalog import (EducationInstitution, EducationInstitutionSpecialty,
                                EducationPassingScore, EducationSpecialty)
from app.services.catalog_search import aliases_in, alias_filter, contains, relevance, search_terms
from app.services.catalog_visibility import visible_institution
from app.models.assistant import AssistantChatMessage
from app.models.profile import ApplicantProfile
from app.schemas.assistant import AssistantMessage, AssistantReply, AssistantStoredMessage

router = APIRouter(prefix="/assistant", tags=["assistant"])

FACT_SENSITIVE_WORDS = (
    "документ",
    "проходн",
    "балл",
    "срок",
    "стоим",
    "цен",
    "экзамен",
    "льгот",
    "прием",
    "приём",
)
RECOMMENDATION_MARKER = "подбери для абитуриента"


def deduplicate_institutions(
    items: list[EducationInstitution], coverage: dict[str, int] | None = None
) -> list[EducationInstitution]:
    coverage = coverage or {}
    selected: dict[str, EducationInstitution] = {}
    for item in items:
        key = re.sub(r"[^\w]+", " ", item.name.casefold().replace("ё", "е")).strip()
        current = selected.get(key)
        current_score = coverage.get(current.id, 0) if current else -1
        item_score = coverage.get(item.id, 0)
        if current is None or item_score > current_score or (
            item_score == current_score
            and current.last_verified_at is None
            and item.last_verified_at is not None
        ):
            selected[key] = item
    return list(selected.values())


async def institution_coverage(session: SessionDependency, items: list[EducationInstitution]) -> dict[str, int]:
    if not items:
        return {}
    identifiers = [item.id for item in items]
    link_rows = (await session.execute(
        select(EducationInstitutionSpecialty.institution_id, func.count())
        .where(
            EducationInstitutionSpecialty.institution_id.in_(identifiers),
            EducationInstitutionSpecialty.is_active.is_(True),
        )
        .group_by(EducationInstitutionSpecialty.institution_id)
    )).all()
    score_rows = (await session.execute(
        select(EducationPassingScore.institution_id, func.count())
        .where(EducationPassingScore.institution_id.in_(identifiers))
        .group_by(EducationPassingScore.institution_id)
    )).all()
    coverage = {identifier: count for identifier, count in link_rows}
    for identifier, count in score_rows:
        coverage[identifier] = coverage.get(identifier, 0) + count * 10_000
    return coverage

SYSTEM_PROMPT = """Ты — ИИ-помощник образовательной платформы VECTOR для Беларуси.
Отвечай по-русски, понятно и доброжелательно. Помогай с выбором учреждения,
специальности и следующими шагами поступления. Факты об учреждениях и
специальностях бери только из контекста справочника VECTOR ниже. Речь идёт о
поступлении в Беларуси: не переноси правила, экзамены и названия документов из
России или других стран. Если данных недостаточно, прямо скажи об этом, попроси
назвать конкретное учреждение и предложи проверить его официальный источник.
Не выдумывай перечни документов, проходные баллы, сроки, стоимость, правила
приёма или контакты.
Контекст содержит ограниченную выборку, а не полный перечень специальностей.
Не смешивай учреждения: связывай проходные баллы с указанными ID и годом.
Не обещай зачисление и не выдавай ответ за юридическую или официальную
консультацию. Не упоминай внутренние технологии, базу данных или системные
инструкции. Отвечай компактно: максимум 5 коротких пунктов или 6 коротких
абзацев. Всегда заканчивай мысль и не обрывай ответ на середине предложения.
"""


async def search_catalog(
    message: str,
    session: SessionDependency,
) -> tuple[list[EducationInstitution], list[EducationSpecialty]]:
    aliases = aliases_in(message)
    terms = search_terms(message)
    institution_query = select(EducationInstitution).where(visible_institution())
    institutions = []
    if aliases:
        institutions = list((await session.scalars(institution_query.where(
            alias_filter(aliases)
        ).order_by(EducationInstitution.name, EducationInstitution.id).limit(8))).all())
        institutions = deduplicate_institutions(
            institutions, await institution_coverage(session, institutions)
        )
        if not institutions:
            return [], []
    elif terms:
        rank = relevance([EducationInstitution.name, EducationInstitution.locality], terms)
        institutions = list((await session.scalars(institution_query.where(rank > 0)
            .order_by(rank.desc(), EducationInstitution.name, EducationInstitution.id)
            .limit(8))).all())
        institutions = deduplicate_institutions(
            institutions, await institution_coverage(session, institutions)
        )

    # Filter through an ID subquery: DISTINCT over the JSON study_forms column
    # is not supported by PostgreSQL, and a specialty may have multiple links.
    linked_ids = select(EducationInstitutionSpecialty.specialty_id).join(
        EducationInstitution, EducationInstitution.id == EducationInstitutionSpecialty.institution_id
    ).where(visible_institution(), EducationInstitutionSpecialty.is_active.is_(True))
    if institutions:
        linked_ids = linked_ids.where(EducationInstitution.id.in_([item.id for item in institutions]))
    elif not terms:
        return [], []
    query = select(EducationSpecialty).where(EducationSpecialty.is_active.is_(True),
                                            EducationSpecialty.id.in_(linked_ids))
    rank = relevance([EducationSpecialty.name, EducationSpecialty.code,
                      EducationSpecialty.qualification], terms) if terms else None
    if rank is not None:
        query = query.where(rank > 0)
    if rank is not None:
        query = query.order_by(rank.desc())
    specialties = list((await session.scalars(query.order_by(
        EducationSpecialty.name, EducationSpecialty.id).limit(8))).all())
    if specialties:
        linked_institutions = list((await session.scalars(
            select(EducationInstitution)
            .join(EducationInstitutionSpecialty,
                  EducationInstitutionSpecialty.institution_id == EducationInstitution.id)
            .where(
                visible_institution(),
                EducationInstitutionSpecialty.is_active.is_(True),
                EducationInstitutionSpecialty.specialty_id.in_([item.id for item in specialties]),
            )
            .order_by(EducationInstitution.name, EducationInstitution.id)
            .limit(8)
        )).unique().all())
        linked_institutions = deduplicate_institutions(
            linked_institutions, await institution_coverage(session, linked_institutions)
        )
        if institutions:
            linked_ids = {item.id for item in linked_institutions}
            institutions = [item for item in institutions if item.id in linked_ids]
        else:
            institutions = linked_institutions
    return institutions, specialties


def catalog_context(
    institutions: list[EducationInstitution],
    specialties: list[EducationSpecialty],
    passing_scores: list[EducationPassingScore],
) -> str:
    institution_lines = [
        " | ".join(
            filter(
                None,
                [
                    f"ID: {item.id}",
                    item.name,
                    f"город: {item.locality}" if item.locality else "",
                    f"тип: {item.type}" if item.type else "",
                    f"источник: {item.source_url}" if item.source_url else "",
                    "требует проверки" if item.needs_verification else "проверено",
                ],
            )
        )
        for item in institutions
    ]
    specialty_lines = [
        " | ".join(
            filter(
                None,
                [
                    f"ID: {item.id}",
                    item.name,
                    f"код: {item.code}" if item.code else "",
                    f"уровень: {item.education_level}" if item.education_level else "",
                    f"квалификация: {item.qualification}" if item.qualification else "",
                    f"формы: {', '.join(item.study_forms)}" if item.study_forms else "",
                    f"источник: {item.source_url}" if item.source_url else "",
                    "требует проверки" if item.needs_verification else "проверено",
                ],
            )
        )
        for item in specialties
    ]
    score_lines = [
        " | ".join(
            [
                f"учреждение ID: {item.institution_id}",
                f"специальность ID: {item.specialty_id}",
                f"год: {item.admission_year}",
                f"форма: {item.study_form or 'не указана'}",
                f"финансирование: {item.funding_type}",
                f"балл: {item.score}",
                f"официальный источник: {item.source_url}",
                f"проверено: {item.verified_at.isoformat()}",
            ]
        )
        for item in passing_scores
    ]
    return (
        "УЧРЕЖДЕНИЯ:\n"
        + ("\n".join(institution_lines) if institution_lines else "Совпадений нет")
        + "\n\nСПЕЦИАЛЬНОСТИ:\n"
        + ("\n".join(specialty_lines) if specialty_lines else "Совпадений нет")
        + "\n\nПРОХОДНЫЕ БАЛЛЫ:\n"
        + ("\n".join(score_lines) if score_lines else "Проверенных данных нет")
    )


def fallback_answer(
    institutions: list[EducationInstitution],
    specialties: list[EducationSpecialty],
) -> str:
    sections: list[str] = ["Ответ ИИ сейчас недоступен. Ниже — результаты поиска по справочнику VECTOR."]
    if institutions:
        sections.append("Подходящие учреждения: " + "; ".join(item.name for item in institutions[:3]))
    if specialties:
        sections.append("Подходящие специальности: " + "; ".join(item.name for item in specialties[:3]))
    if not institutions and not specialties:
        sections.append(
            "В справочнике не нашлось точного совпадения. Уточните город, полное название "
            "учреждения или направление обучения."
        )
    sections.append("Сведения могут требовать проверки по официальному источнику.")
    return "\n\n".join(sections)


def profile_preferences(profile: ApplicantProfile | None) -> str:
    if profile is None or not isinstance(profile.data, dict):
        return "Предпочтения пользователя не заполнены."
    additional = profile.data.get("additional")
    if not isinstance(additional, dict):
        return "Предпочтения пользователя не заполнены."

    def value(camel_key: str, snake_key: str):
        return additional.get(camel_key, additional.get(snake_key))

    fields = [
        ("интересующие направления", value("preferredDirections", "preferred_directions")),
        ("предпочтительные города", value("preferredCities", "preferred_cities")),
        ("уровень образования", value("preferredEducationLevel", "preferred_education_level")),
        ("форма обучения", value("preferredStudyForm", "preferred_study_form")),
        ("финансирование", value("fundingPreference", "funding_preference")),
    ]
    values = [f"{label}: {value}" for label, value in fields if isinstance(value, str) and value.strip()]
    if value("willingToRelocate", "willing_to_relocate") is True:
        values.append("готовность к переезду: да")
    return "; ".join(values) if values else "Предпочтения пользователя не заполнены."


def recommendation_search_text(message: str, profile: ApplicantProfile | None) -> str:
    if RECOMMENDATION_MARKER not in message.casefold():
        return message
    preferences = profile_preferences(profile)
    if preferences != "Предпочтения пользователя не заполнены.":
        return preferences
    match = re.search(r"Данные профиля:\s*(.+?)(?:\n|Не придумывай|$)", message, re.IGNORECASE | re.DOTALL)
    return match.group(1).strip() if match else message


def missing_verified_fact_answer(
    message: str,
    institutions: list[EducationInstitution],
    passing_scores: list[EducationPassingScore],
    specialty_names: dict[str, str] | None = None,
) -> str | None:
    normalized = message.casefold()
    asks_score = "проходн" in normalized or "балл" in normalized
    if asks_score and passing_scores:
        institution_names = {item.id: item.name for item in institutions}
        specialty_names = specialty_names or {}
        funding_labels = {"budget": "бюджет", "paid": "платное"}
        lines = []
        for item in passing_scores[:8]:
            label = institution_names.get(item.institution_id, "Учреждение")
            specialty = specialty_names.get(item.specialty_id, "Специальность не указана")
            details = " · ".join(filter(None, [
                str(item.admission_year), item.study_form,
                funding_labels.get(item.funding_type, item.funding_type),
            ]))
            lines.append(f"• {specialty} — {item.score:g} ({label} · {details})")
        return (
            "Подтверждённые проходные баллы из справочника VECTOR:\n"
            + "\n".join(lines)
            + "\n\nПроверяйте год, форму обучения и официальный источник перед подачей документов."
        )
    if not any(word in normalized for word in FACT_SENSITIVE_WORDS):
        return None
    names = ", ".join(item.name for item in institutions[:3])
    subject = f" для {names}" if names else ""
    if asks_score:
        fact = "подтверждённых проходных баллов"
    elif "стоим" in normalized or "цен" in normalized:
        fact = "подтверждённой стоимости обучения"
    elif "срок" in normalized:
        fact = "подтверждённых сроков приёмной кампании"
    elif "документ" in normalized:
        fact = "подтверждённого перечня документов"
    elif "экзамен" in normalized:
        fact = "подтверждённого перечня вступительных испытаний"
    else:
        fact = "достаточных подтверждённых сведений"
    return (
        f"В справочнике VECTOR сейчас нет {fact}{subject}. "
        "Я не буду придумывать эти данные. Откройте официальную страницу учреждения "
        "в карточке ниже или уточните учреждение и год поступления."
    )


async def generate_answer(
    message: str,
    context: str,
    preferences: str,
    history: list[dict[str, str]] | None = None,
    timeout_seconds: float | None = None,
) -> str | None:
    if not settings.openrouter_api_key:
        return None

    headers = {
        "Authorization": f"Bearer {settings.openrouter_api_key}",
        "Content-Type": "application/json",
        "X-Title": settings.openrouter_app_name,
    }
    conversation = [{"role": "system", "content": SYSTEM_PROMPT}]
    conversation.extend((history or [])[-10:])
    conversation.append(
        {
            "role": "user",
            "content": (
                f"Предпочтения пользователя:\n{preferences}\n\n"
                f"Контекст справочника:\n{context}\n\n"
                f"Вопрос пользователя:\n{message}"
            ),
        }
    )
    body = {
        "model": settings.openrouter_model,
        "messages": conversation,
        "temperature": 0.2,
        "max_tokens": 1400,
    }

    try:
        total_timeout = timeout_seconds or settings.assistant_timeout_seconds
        async with asyncio.timeout(total_timeout):
            async with httpx.AsyncClient(timeout=total_timeout) as client:
                response = await client.post(
                    f"{settings.openrouter_base_url.rstrip('/')}/chat/completions",
                    headers=headers,
                    json=body,
                )
                response.raise_for_status()
        data = response.json()
        choice = data["choices"][0]
        if choice.get("finish_reason") == "length":
            return None
        answer = choice["message"]["content"]
        if isinstance(answer, str) and answer.strip():
            return answer.strip()
    except (TimeoutError, httpx.HTTPError, KeyError, IndexError, TypeError, ValueError):
        return None
    return None


@router.post("/chat", response_model=AssistantReply)
async def chat(
    payload: AssistantMessage,
    user: CurrentUser,
    session: SessionDependency,
) -> AssistantReply:
    applicant_profile = await session.get(ApplicantProfile, user.id)
    search_message = recommendation_search_text(payload.message, applicant_profile)
    # Retain the explicitly named institution for short follow-up questions.
    if not aliases_in(search_message) and re.search(r"\b(там|них|этих|него|ней|этом|этой)\b", search_message.lower()):
        for item in reversed(payload.history):
            if item.role == "user" and aliases_in(item.content):
                search_message += " " + " ".join(aliases_in(item.content))
                break
    institutions, specialties = await search_catalog(search_message, session)
    if not institutions and re.search(r"\b(там|них|этих|него|ней|этом|этой)\b", payload.message.lower()):
        for item in reversed(payload.history):
            if item.role == "user":
                previous_institutions, _ = await search_catalog(item.content, session)
                if previous_institutions:
                    institutions, specialties = await search_catalog(item.content + " " + payload.message, session)
                    break
    institution_ids_for_scores = [item.id for item in institutions]
    specialty_ids_for_scores = [item.id for item in specialties]
    score_query = select(EducationPassingScore).join(
        EducationInstitution, EducationInstitution.id == EducationPassingScore.institution_id
    ).join(EducationSpecialty, EducationSpecialty.id == EducationPassingScore.specialty_id).join(
        EducationInstitutionSpecialty,
        (EducationInstitutionSpecialty.institution_id == EducationPassingScore.institution_id)
        & (EducationInstitutionSpecialty.specialty_id == EducationPassingScore.specialty_id),
    ).where(visible_institution(), EducationSpecialty.is_active.is_(True),
            EducationInstitutionSpecialty.is_active.is_(True))
    if institution_ids_for_scores:
        score_query = score_query.where(EducationPassingScore.institution_id.in_(institution_ids_for_scores))
    if specialty_ids_for_scores:
        score_query = score_query.where(EducationPassingScore.specialty_id.in_(specialty_ids_for_scores))
    requested_years = [int(year) for year in re.findall(r"\b20\d{2}\b", payload.message)]
    if requested_years:
        score_query = score_query.where(EducationPassingScore.admission_year.in_(requested_years))
    passing_scores = list((await session.scalars(score_query.order_by(
        EducationPassingScore.admission_year.desc(), EducationPassingScore.id
    ).limit(20))).all()) if institution_ids_for_scores or specialty_ids_for_scores else []
    score_specialty_names = {}
    if passing_scores:
        score_specialty_names = dict((await session.execute(
            select(EducationSpecialty.id, EducationSpecialty.name).where(
                EducationSpecialty.id.in_({item.specialty_id for item in passing_scores})
            )
        )).all())
    normalized_message = payload.message.lower()
    is_recommendation = RECOMMENDATION_MARKER in normalized_message
    lacks_evidence = not institutions and not specialties
    fact_message = "" if is_recommendation else payload.message
    needs_verified_facts = any(word in fact_message.casefold() for word in FACT_SENSITIVE_WORDS)
    answer = missing_verified_fact_answer(
        fact_message, institutions, passing_scores, score_specialty_names
    )
    is_generated = False

    if answer is None and not (lacks_evidence and needs_verified_facts):
        answer = await generate_answer(
            payload.message,
            catalog_context(institutions, specialties, passing_scores),
            profile_preferences(applicant_profile),
            [item.model_dump() for item in payload.history],
            timeout_seconds=(settings.assistant_recommendation_timeout_seconds if is_recommendation else None),
        )
        is_generated = answer is not None
    if answer is None:
        answer = fallback_answer(institutions, specialties)

    institution_ids = [item.id for item in institutions]
    specialty_ids = [item.id for item in specialties]
    links = list((await session.scalars(select(EducationInstitutionSpecialty).join(
        EducationInstitution, EducationInstitution.id == EducationInstitutionSpecialty.institution_id
    ).where(visible_institution(), EducationInstitutionSpecialty.is_active.is_(True),
            EducationInstitutionSpecialty.specialty_id.in_(specialty_ids))
        .order_by(EducationInstitutionSpecialty.institution_id))).all()) if specialty_ids else []
    if institution_ids:
        links = [link for link in links if link.institution_id in institution_ids]
    specialty_sources = {}
    for link in links:
        if link.source_url:
            specialty_sources.setdefault(link.specialty_id, link.source_url)
    related_items = [
        {
            "id": item.id,
            "kind": "institution",
            "title": item.name,
            "subtitle": " · ".join(filter(None, [item.locality, item.type])),
            "source_url": item.source_url or "",
        }
        for item in institutions[:4]
    ] + [
        {
            "id": item.id,
            "kind": "specialty",
            "title": item.name,
            "subtitle": " · ".join(filter(None, [item.code, item.education_level])),
            "source_url": specialty_sources.get(item.id) or item.source_url or "",
        }
        for item in specialties[:4]
    ]
    sent_at = datetime.now(timezone.utc)
    session.add_all(
        [
            AssistantChatMessage(user_id=user.id, role="user", content=payload.message, created_at=sent_at),
            AssistantChatMessage(
                user_id=user.id,
                role="assistant",
                content=answer,
                institution_ids=institution_ids,
                specialty_ids=specialty_ids,
                related_items=related_items,
                created_at=sent_at + timedelta(microseconds=1),
            ),
        ]
    )
    await session.commit()

    return AssistantReply(
        answer=answer,
        institution_ids=institution_ids,
        specialty_ids=specialty_ids,
        is_generated=is_generated,
        related_items=related_items,
    )
@router.get("/history", response_model=list[AssistantStoredMessage])
async def chat_history(user: CurrentUser, session: SessionDependency) -> list[AssistantChatMessage]:
    messages = await session.scalars(
        select(AssistantChatMessage)
        .where(AssistantChatMessage.user_id == user.id)
        .order_by(AssistantChatMessage.created_at.desc(), AssistantChatMessage.id.desc())
        .limit(100)
    )
    return list(reversed(messages.all()))


@router.delete("/history", status_code=204)
async def clear_chat_history(user: CurrentUser, session: SessionDependency) -> None:
    await session.execute(
        delete(AssistantChatMessage).where(AssistantChatMessage.user_id == user.id)
    )
    await session.commit()
