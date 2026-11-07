from unittest.mock import patch

import httpx
import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.database import Base, get_session
from app.main import app
from app.models import User
from app.models.enums import UserRole, UserStatus
from app.services.google_auth import verify_google_token


@pytest.fixture
async def google_client(tmp_path):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'google.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def sessions():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_session] = sessions
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test/api/v1",
        ) as client:
            yield client, factory
    finally:
        app.dependency_overrides.pop(get_session, None)
        await engine.dispose()


async def test_google_registration_repeat_login_and_refresh(google_client):
    client, _ = google_client
    claims = {"sub": "google-subject", "email": "new@gmail.com", "email_verified": True, "name": "New User"}
    with patch("app.services.google_auth.verify_google_token", return_value=claims):
        first = await client.post("/auth/google", json={"id_token": "verified-by-mock"})
        assert first.status_code == 200, first.text
        repeated = await client.post("/auth/google", json={"id_token": "verified-by-mock", "role": "institution"})
    assert repeated.status_code == 200
    assert repeated.json()["user"]["id"] == first.json()["user"]["id"]
    assert repeated.json()["user"]["role"] == "applicant"
    refreshed = await client.post("/auth/refresh", json={"refresh_token": first.json()["refresh_token"]})
    assert refreshed.status_code == 200
    headers = {"Authorization": "Bearer " + refreshed.json()["access_token"]}
    assert (await client.get("/auth/me", headers=headers)).json()["email"] == "new@gmail.com"


@pytest.mark.parametrize("email,blocked,expected", [
    ("existing@gmail.com", False, 200),
    ("existing@example.com", False, 409),
    ("existing@gmail.com", True, 403),
])
async def test_existing_account_linking(google_client, email, blocked, expected):
    client, factory = google_client
    async with factory() as session:
        user = User(email=email, full_name="Existing", role=UserRole.EMPLOYER,
                    status=UserStatus.BLOCKED if blocked else UserStatus.ACTIVE,
                    email_verified=True)
        session.add(user)
        await session.commit()
        identifier = str(user.id)
    claims = {"sub": "google-subject", "email": email, "email_verified": True}
    with patch("app.services.google_auth.verify_google_token", return_value=claims):
        response = await client.post("/auth/google", json={"id_token": "verified-by-mock"})
    assert response.status_code == expected, response.text
    if expected == 200:
        assert response.json()["user"]["id"] == identifier
        assert response.json()["user"]["role"] == "employer"


async def test_google_rejects_privileged_role_and_invalid_token(google_client):
    client, _ = google_client
    response = await client.post("/auth/google", json={"id_token": "invalid", "role": "admin"})
    assert response.status_code == 400
    with patch("app.services.google_auth.verify_google_token", side_effect=HTTPException(401, "Invalid")):
        assert (await client.post("/auth/google", json={"id_token": "invalid"})).status_code == 401


def test_verifier_checks_audience_and_email(monkeypatch):
    monkeypatch.setattr("app.services.google_auth.settings.google_client_id", "our-client")
    with patch("app.services.google_auth.id_token.verify_oauth2_token", return_value={
        "sub": "subject", "email": "new@gmail.com", "email_verified": True,
    }) as verify:
        assert verify_google_token("signed-token")["sub"] == "subject"
        assert verify.call_args.args[2] == "our-client"
    with patch("app.services.google_auth.id_token.verify_oauth2_token", side_effect=ValueError("expired")):
        with pytest.raises(HTTPException) as error:
            verify_google_token("expired-token")
        assert error.value.status_code == 401
    with patch("app.services.google_auth.id_token.verify_oauth2_token", return_value={
        "sub": "subject", "email": "new@gmail.com", "email_verified": False,
    }):
        with pytest.raises(HTTPException):
            verify_google_token("unverified-email-token")
