from datetime import date

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.routes.assistant import (
    catalog_context,
    deduplicate_institutions,
    fallback_answer,
    missing_verified_fact_answer,
    recommendation_search_text,
    search_catalog,
)
from app.api.routes.catalog import institutions, passing_scores_for_institution
from app.core.database import Base
from app.models.catalog import EducationInstitution as Institution
from app.models.catalog import EducationInstitutionSpecialty as Link
from app.models.catalog import EducationPassingScore as Score
from app.models.catalog import EducationSpecialty as Specialty
from app.models.catalog import EducationCatalogMetadata
from app.models.institution_workspace import InstitutionProfile
from app.models.organization import Organization
from app.models.user import User
from app.services.catalog_search import aliases_in


@pytest.fixture
async def catalog(tmp_path):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'catalog.db'}")

    @event.listens_for(engine.sync_engine, "connect")
    def unicode_lower(connection, _):
        connection.create_function("lower", 1, lambda value: value.lower() if value else value)

    async with engine.begin() as connection:
        await connection.run_sync(lambda c: Base.metadata.create_all(c, tables=[
            model.__table__ for model in [User, Organization, Institution, Specialty, Link,
                                         InstitutionProfile, Score, EducationCatalogMetadata]
        ]))
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with factory() as session:
        session.add_all([
            Institution(id="grsu", name="Гродненский государственный университет имени Янки Купалы", locality="Гродно"),
            Institution(id="bsuir", name="Белорусский государственный университет информатики и радиоэлектроники"),
            Institution(id="bsu", name="Белорусский государственный университет"),
            Institution(id="branch", name="Филиал Белорусский государственный университет информатики и радиоэлектроники — колледж"),
            Institution(id="other", name="Другой университет", locality="Минск"),
            Institution(id="hidden", name="Гродненский государственный университет имени Янки Купалы — архив", is_active=False),
            Specialty(id="grsu-math", name="Математика", code="6-05-0533-01"),
            Specialty(id="other-math", name="Математика другого вуза"),
            Specialty(id="archived", name="Архивная специальность", is_active=False),
            Specialty(id="inactive-link", name="Снятое направление"),
        ])
        await session.flush()
        session.add_all([
            Link(institution_id="grsu", specialty_id="grsu-math", source_url="https://example.org/grsu"),
            Link(institution_id="other", specialty_id="other-math"),
            Link(institution_id="grsu", specialty_id="archived"),
            Link(institution_id="grsu", specialty_id="inactive-link", is_active=False),
            Score(id="hidden-score", institution_id="hidden", specialty_id="grsu-math",
                  admission_year=2026, score=300, source_url="https://example.org", verified_at=date.today()),
        ])
        await session.commit()
        yield session
    await engine.dispose()


@pytest.mark.parametrize("question", ["ГрГУ", "Какие варианты есть в ГрГУ? Покажи записи из справочника и источники",
                                       "Пожалуйста помоги мне подобрать варианты обучения и покажи направления в ГрГУ"])
async def test_alias_returns_only_linked_active_specialties(catalog, question):
    found, specialties = await search_catalog(question, catalog)
    assert [item.id for item in found] == ["grsu"]
    assert [item.id for item in specialties] == ["grsu-math"]


async def test_bsuir_is_not_bsu(catalog):
    assert aliases_in("В БГУИР, а не БГУ?") == ["бгуир", "бгу"]
    found, _ = await search_catalog("БГУИР", catalog)
    assert [item.id for item in found] == ["bsuir"]
    found, _ = await search_catalog("БГУ", catalog)
    assert [item.id for item in found] == ["bsu"]


async def test_catalog_uses_same_alias_and_city_search(catalog):
    found = await institutions(catalog, search="ГрГУ", institution_type=None, limit=50, offset=0)
    assert [item.id for item in found] == ["grsu"]
    found = await institutions(catalog, search="Минск", institution_type=None, limit=50, offset=0)
    assert [item.id for item in found] == ["other"]


async def test_hidden_institution_scores_are_not_public(catalog):
    assert await passing_scores_for_institution("hidden", catalog, year=None) == []


async def test_context_labels_ids_and_fallback_is_honest(catalog):
    found, specialties = await search_catalog("ГрГУ", catalog)
    context = catalog_context(found, specialties, [])
    assert "ID: grsu" in context and "ID: grsu-math" in context
    assert "Можно рассмотреть" in fallback_answer("Расскажи про ГрГУ", found, specialties)
    assert "три вопроса" in fallback_answer("Помоги выбрать", [], [])


async def test_fallback_continues_conversation_about_omitted_institution(catalog):
    found, specialties = await search_catalog("Почему ты не предложил БГУИР?", catalog)
    answer = fallback_answer("Почему ты не предложил БГУИР?", found, specialties)
    assert "не означает" in answer
    assert "БГУИР" in answer or "информатики и радиоэлектроники" in answer
    assert "что важнее" in answer


def test_fallback_greeting_asks_about_interests():
    answer = fallback_answer("Привет!", [], [])
    assert "Что вам ближе" in answer
    assert "городе" in answer


async def test_no_arbitrary_results_for_generic_or_unknown_question(catalog):
    assert await search_catalog("Помоги подобрать направление", catalog) == ([], [])
    assert await search_catalog("несуществующийинститут", catalog) == ([], [])


async def test_specialty_search_returns_its_institution(catalog):
    institutions, specialties = await search_catalog("математика", catalog)
    assert [item.id for item in specialties] == ["grsu-math", "other-math"]
    assert [item.id for item in institutions] == ["grsu", "other"]


def test_recommendation_search_uses_profile_payload_instead_of_instructions():
    message = """Подбери для абитуриента 3 варианта.
    Данные профиля: интересующие направления: математика; город: Гродно.
    Не придумывай проходные баллы."""
    assert recommendation_search_text(message, None) == (
        "интересующие направления: математика; город: Гродно."
    )


def test_sensitive_fact_without_evidence_is_not_generated(catalog):
    institution = Institution(id="test", name="Тестовый университет")
    answer = missing_verified_fact_answer("Какой проходной балл?", [institution], [])
    assert "нет подтверждённых проходных баллов" in answer
    assert "не буду придумывать" in answer
    assert missing_verified_fact_answer("Подбери специальность", [institution], []) is None


def test_verified_score_answer_uses_stored_year_and_value():
    institution = Institution(id="test", name="Тестовый университет")
    score = Score(
        id="score",
        institution_id="test",
        specialty_id="specialty",
        admission_year=2026,
        study_form="очная",
        funding_type="бюджет",
        score=321,
        source_url="https://example.org/official",
        verified_at=date.today(),
    )
    answer = missing_verified_fact_answer(
        "Какой проходной балл?", [institution], [score], {"specialty": "Математика"}
    )
    assert all(value in answer for value in ["321", "2026", "Тестовый университет", "Математика"])


def test_duplicate_institution_names_prefer_verified_record():
    duplicate = Institution(id="import", name="Одинаковый университет")
    verified = Institution(id="verified", name="Одинаковый университет", last_verified_at=date.today())
    assert [item.id for item in deduplicate_institutions([duplicate, verified])] == ["verified"]


def test_duplicate_institution_names_prefer_record_with_catalog_coverage():
    sparse = Institution(id="sparse", name="Одинаковый университет", last_verified_at=date.today())
    complete = Institution(id="complete", name="Одинаковый университет")
    assert [item.id for item in deduplicate_institutions(
        [sparse, complete], {"sparse": 2, "complete": 10_013}
    )] == ["complete"]


async def test_contact_import_dry_run_idempotency_and_evidence(catalog, tmp_path, monkeypatch):
    import json
    from app.scripts import import_verified_contacts as importer
    monkeypatch.setattr(importer, "SessionFactory", async_sessionmaker(catalog.bind, expire_on_commit=False))
    path = tmp_path / "contacts.json"
    path.write_text(json.dumps([{
        "institution_ids": ["grsu"], "checked_at": date.today().isoformat(),
        "source_url": "https://example.org/contacts",
        "fields": {"admissions_phone": "+375 17 123 45 67"},
    }]))
    assert len(await importer.apply(path)) == 1
    catalog.expire_all()
    assert (await catalog.get(Institution, "grsu")).admissions_phone == ""
    assert len(await importer.apply(path, commit=True)) == 1
    assert await importer.apply(path, commit=True) == []
    catalog.expire_all()
    institution = await catalog.get(Institution, "grsu")
    assert institution.needs_verification is True
    evidence = await catalog.get(EducationCatalogMetadata, "verified_contacts:grsu")
    assert evidence.value["admissions_phone"]["previous_value"] == ""
    assert evidence.value["admissions_phone"]["source_url"] == "https://example.org/contacts"
