from unittest.mock import AsyncMock

import httpx
import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.database import Base, get_session
from app.core.security import hash_password
from app.main import app
from app.models import Organization, OrganizationMembership, User
from app.models.enums import (
    MembershipRole, OrganizationType, UserRole, UserStatus, VerificationStatus,
)


@pytest.fixture
async def journey(tmp_path, monkeypatch):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'journey.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def sessions():
        async with factory() as session:
            yield session

    # This scenario exercises the API without sending mail or touching live user data.
    monkeypatch.setattr("app.api.routes.auth.send_action_email", AsyncMock())
    app.dependency_overrides[get_session] = sessions
    try:
        async with factory() as session:
            for index in range(2):
                owner = User(
                    email=f"owner{index}@example.com", full_name="Owner",
                    role=UserRole.INSTITUTION, status=UserStatus.ACTIVE,
                    email_verified=True, password_hash=hash_password("journey-password"),
                )
                session.add(owner)
                await session.flush()
                organization = Organization(
                    name="Same University", type=OrganizationType.INSTITUTION,
                    created_by_id=owner.id, status=VerificationStatus.ACTIVE,
                )
                session.add(organization)
                await session.flush()
                session.add(OrganizationMembership(
                    user_id=owner.id, organization_id=organization.id, role=MembershipRole.OWNER,
                ))
            await session.commit()
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test/api/v1",
        ) as client:
            owners = []
            for index in range(2):
                login = await client.post("/auth/login", json={
                    "email": f"owner{index}@example.com", "password": "journey-password",
                })
                assert login.status_code == 200, login.text
                owners.append({"Authorization": "Bearer " + login.json()["access_token"]})
            workspace = await client.get("/institutions/workspace", headers=owners[0])
            assert workspace.status_code == 200, workspace.text
            institution_id = workspace.json()["profile"]["catalog_institution_id"]
            published = await client.put("/institutions/workspace/profile", headers=owners[0], json={
                "city": "Минск", "address": "Адрес 1", "phone": "123456789",
                "email": "admissions@example.com", "published": True, "revision": 0,
            })
            assert published.status_code == 200, published.text
            program = await client.post("/institutions/workspace/programs", headers=owners[0], json={
                "name": "Информатика", "code": "6-05", "duration": 4,
                "budget_places": 30, "paid_places": 20, "revision": 0, "status": "published",
            })
            assert program.status_code == 201, program.text
            registration = await client.post("/auth/register", json={
                "email": "applicant@example.com", "password": "journey-password",
                "full_name": "Test Applicant", "role": "applicant",
            })
            assert registration.status_code == 201, registration.text
            applicant = {"Authorization": "Bearer " + registration.json()["access_token"]}
            yield client, owners, applicant, {
                "institution_id": institution_id,
                "specialty_id": program.json()["specialty_id"], "priority": 1,
            }, factory
    finally:
        app.dependency_overrides.pop(get_session, None)
        await engine.dispose()


async def test_profile_application_decision_and_notification(journey):
    client, owners, applicant, payload, _ = journey
    profile = {"schema_version": 1, "completion_percentage": 100,
               "data": {"personal": {"firstName": "Test"}}}
    saved = await client.put("/profile", headers=applicant, json=profile)
    assert saved.status_code == 200, saved.text
    assert (await client.get("/profile", headers=applicant)).json()["data"] == profile["data"]
    catalog = await client.get("/catalog/institutions")
    assert payload["institution_id"] in [item["id"] for item in catalog.json()]
    created = await client.post("/applications", headers=applicant, json=payload)
    assert created.status_code == 201, created.text
    application_id = created.json()["id"]
    queue = await client.get("/applications/organization", headers=owners[0])
    assert queue.status_code == 200, queue.text
    assert queue.json()[0]["id"] == application_id
    assert queue.json()[0]["applicant_profile"] == profile["data"]
    decision = await client.patch(
        f"/applications/organization/{application_id}/status", headers=owners[0],
        json={"status": "accepted", "comment": "Документы проверены"},
    )
    assert decision.status_code == 200, decision.text
    applications = (await client.get("/applications", headers=applicant)).json()
    assert applications[0]["status"] == "accepted"
    assert applications[0]["history"][-1]["details"] == "Документы проверены"
    notifications = (await client.get("/notifications", headers=applicant)).json()
    assert len(notifications) == 1
    assert notifications[0]["entity_id"] == application_id
    read = await client.patch(f"/notifications/{notifications[0]['id']}/read", headers=applicant)
    assert read.status_code == 200 and read.json()["is_read"]


async def test_same_name_organization_cannot_access_application(journey):
    client, owners, applicant, payload, _ = journey
    created = await client.post("/applications", headers=applicant, json=payload)
    assert created.status_code == 201, created.text
    application_id = created.json()["id"]
    queue = await client.get("/applications/organization", headers=owners[1])
    assert queue.status_code == 200 and queue.json() == []
    for resource in ["documents", "comments"]:
        response = await client.get(f"/applications/{application_id}/{resource}", headers=owners[1])
        assert response.status_code == 403
    decision = await client.patch(
        f"/applications/organization/{application_id}/status", headers=owners[1],
        json={"status": "accepted"},
    )
    assert decision.status_code == 404


@pytest.mark.parametrize("status", ["accepted", "rejected", "documentsReview"])
async def test_applicant_cannot_create_a_decision(journey, status):
    client, _, applicant, payload, _ = journey
    response = await client.post("/applications", headers=applicant, json={**payload, "status": status})
    assert response.status_code == 422
