import httpx
import pytest
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.commands.demo_admin import provision_demo_admin
from app.core.config import settings
from app.core.database import Base, get_session
from app.main import app
from app.models import User, Organization, OrganizationMembership, RefreshToken
from app.schemas.auth import LoginRequest
from app.models.enums import OrganizationType


@pytest.mark.asyncio
async def test_demo_admin_login_and_moderation_access(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "environment", "development")
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'admin.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        tables = [m.__table__ for m in (User, Organization, OrganizationMembership, RefreshToken)]
        await connection.run_sync(lambda c: Base.metadata.create_all(c, tables=tables))
    async def override():
        async with factory() as session:
            yield session
    app.dependency_overrides[get_session] = override
    try:
        async with factory() as session:
            user = await provision_demo_admin(session)
            original_hash = user.password_hash
            again = await provision_demo_admin(session)
            assert again.id == user.id and again.password_hash == original_hash
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post('/api/v1/auth/login', json={"email": "admin", "password": "admin"})
            assert response.status_code == 200, response.text
            assert response.json()['user']['role'] == 'admin'
            headers = {"Authorization": "Bearer " + response.json()['access_token']}
            assert (await client.get('/api/v1/organizations/admin', headers=headers)).status_code == 200
            for kind in OrganizationType:
                async with factory() as session:
                    organization = Organization(type=kind, name="Test organization", created_by_id=user.id)
                    session.add(organization)
                    await session.commit()
                    organization_id = str(organization.id)
                approved = await client.patch(f'/api/v1/organizations/{organization_id}/status',
                                              headers=headers, json={"status": "active"})
                assert approved.status_code == 200, approved.text
                assert approved.json()["status"] == "active"
            assert (await client.post('/api/v1/auth/login', json={"email": "admin", "password": "incorrect"})).status_code == 401
        monkeypatch.setattr(settings, "environment", "production")
        with pytest.raises(ValidationError):
            LoginRequest(email="admin", password="admin")
        async with factory() as session:
            with pytest.raises(RuntimeError):
                await provision_demo_admin(session)
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()
