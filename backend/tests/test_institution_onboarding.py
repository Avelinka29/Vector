import re

import httpx
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.database import Base, get_session
from app.core.security import hash_password
from app.main import app
from app.models import ActionToken, EmailOutbox, Organization, OrganizationMembership, RefreshToken, User
from app.models.enums import UserRole, UserStatus


@pytest.mark.asyncio
async def test_email_before_mobile_admin_approval(tmp_path):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'test.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        tables = [m.__table__ for m in [User, Organization, OrganizationMembership, RefreshToken, ActionToken, EmailOutbox]]
        await connection.run_sync(lambda c: Base.metadata.create_all(c, tables=tables))

    async def session_override():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_session] = session_override
    try:
        async with factory() as session:
            admin = User(email="admin@example.com", full_name="Admin", role=UserRole.ADMIN,
                         status=UserStatus.ACTIVE, email_verified=True,
                         password_hash=hash_password("test-admin-password"))
            session.add(admin)
            await session.commit()
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            admin_login = await client.post('/api/v1/auth/login', json={"email":"admin@example.com","password":"test-admin-password"})
            admin_headers = {"Authorization": "Bearer " + admin_login.json()["access_token"]}
            registration = await client.post('/api/v1/organizations/register-institution', json={
                "email":"institution@example.com", "password":"test-institution-password",
                "contact_name":"Test Owner", "name":"Test University", "legal_name":"Test University Full",
                "tax_id":"123456789", "city":"Минск", "address":"Тестовая, 1", "phone":"123456789",
            })
            assert registration.status_code == 201, registration.text
            headers = {"Authorization": "Bearer " + registration.json()["access_token"]}
            state = (await client.get('/api/v1/organizations/onboarding', headers=headers)).json()
            org_id = state["organization"]["id"]
            assert not state["email_verified"] and not state["access_granted"]
            assert (await client.get('/api/v1/organizations/admin', headers=admin_headers)).json() == []
            early = await client.patch(f'/api/v1/organizations/{org_id}/status', headers=admin_headers, json={"status":"active"})
            assert early.status_code == 409
            async with factory() as session:
                queued = (await session.scalars(select(EmailOutbox))).one()
                token = re.search(r'token=([^\s]+)', queued.body).group(1)
                assert queued.sent_at is None
            confirmed = await client.post('/api/v1/auth/email/verification/confirm', json={"token":token})
            assert confirmed.status_code == 200, confirmed.text
            assert (await client.post('/api/v1/auth/email/verification/confirm', json={"token":token})).status_code == 400
            pending = (await client.get('/api/v1/organizations/onboarding', headers=headers)).json()
            assert pending["email_verified"] and not pending["access_granted"]
            assert len((await client.get('/api/v1/organizations/admin', headers=admin_headers)).json()) == 1
            assert (await client.patch(f'/api/v1/organizations/{org_id}/status', headers=headers, json={"status":"active"})).status_code == 403
            approved = await client.patch(f'/api/v1/organizations/{org_id}/status', headers=admin_headers, json={"status":"active"})
            assert approved.status_code == 200, approved.text
            assert (await client.get('/api/v1/organizations/onboarding', headers=headers)).json()["access_granted"]
            await client.patch(f'/api/v1/organizations/{org_id}/status', headers=admin_headers, json={"status":"active"})
            async with factory() as session:
                emails = list((await session.scalars(select(EmailOutbox))).all())
                assert len(emails) == 2  # Verification plus one approval; repeated approval is idempotent.
                assert "подтверждено" in emails[1].subject
            await client.patch(f'/api/v1/organizations/{org_id}/status', headers=admin_headers, json={"status":"needs_clarification"})
            assert not (await client.get('/api/v1/organizations/onboarding', headers=headers)).json()["access_granted"]
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()
