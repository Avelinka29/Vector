from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock
from urllib.parse import parse_qs, urlparse

import httpx
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.database import Base, get_session
from app.core.security import hash_password
from app.main import app
from app.models import ActionToken, User
from app.models.enums import UserRole, UserStatus
from app.services import email


@pytest.fixture
async def reset_client(tmp_path, monkeypatch):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'reset.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async def sessions():
        async with factory() as session:
            yield session
    app.dependency_overrides[get_session] = sessions
    mail = AsyncMock()
    monkeypatch.setattr("app.api.routes.auth.send_action_email", mail)
    try:
        async with factory() as session:
            session.add(User(email="reset@example.com", full_name="Reset User",
                             role=UserRole.APPLICANT, status=UserStatus.ACTIVE,
                             password_hash=hash_password("old-password")))
            await session.commit()
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                    base_url="http://test/api/v1/auth") as client:
            yield client, factory, mail
    finally:
        app.dependency_overrides.pop(get_session, None)
        await engine.dispose()


async def request_reset(client, mail):
    response = await client.post("/password/reset/request", json={"email": "reset@example.com"})
    assert response.status_code == 200
    assert response.json().get("debug_token") is None
    return parse_qs(urlparse(mail.call_args.args[3]).query)["token"][0]


async def test_reset_login_reuse_and_refresh_revocation(reset_client):
    client, _, mail = reset_client
    login = await client.post("/login", json={"email": "reset@example.com", "password": "old-password"})
    assert login.status_code == 200
    token = await request_reset(client, mail)
    body = {"token": token, "new_password": "new-password-123"}
    assert (await client.post("/password/reset/confirm", json=body)).status_code == 200
    assert (await client.post("/password/reset/confirm", json=body)).status_code == 400
    assert (await client.post("/login", json={"email": "reset@example.com", "password": "old-password"})).status_code == 401
    assert (await client.post("/login", json={"email": "reset@example.com", "password": "new-password-123"})).status_code == 200
    assert (await client.post("/refresh", json={"refresh_token": login.json()["refresh_token"]})).status_code == 401


async def test_expired_link_and_unknown_email(reset_client):
    client, factory, mail = reset_client
    token = await request_reset(client, mail)
    async with factory() as session:
        stored = (await session.scalars(select(ActionToken))).one()
        stored.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        await session.commit()
    assert (await client.post("/password/reset/confirm", json={"token": token, "new_password": "new-password"})).status_code == 400
    mail.reset_mock()
    response = await client.post("/password/reset/request", json={"email": "unknown@example.com"})
    assert response.status_code == 200 and response.json().get("debug_token") is None
    mail.assert_not_called()


async def test_delivery_failure_is_not_reported_as_success(monkeypatch):
    monkeypatch.setattr(email, "deliver_message", AsyncMock(side_effect=TimeoutError()))
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as error:
        await email.send_action_email("reset@example.com", "Reset", "Reset", "vector://auth/reset-password?token=secret")
    assert error.value.status_code == 503
    assert "secret" not in error.value.detail


async def test_gmail_sends_mime_message_over_https(monkeypatch):
    import base64
    import json
    calls = []
    def handler(request):
        calls.append(request)
        if request.url.host == "oauth2.googleapis.com":
            return httpx.Response(200, json={"access_token": "test-access"})
        assert request.headers["Authorization"] == "Bearer test-access"
        raw = base64.urlsafe_b64decode(json.loads(request.content)["raw"])
        assert b"To: reset@example.com" in raw
        return httpx.Response(200, json={"id": "message-id"})
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    monkeypatch.setattr(email.httpx, "AsyncClient", lambda **kwargs: client)
    for key, value in {"email_transport": "gmail", "gmail_client_id": "test-client",
                       "gmail_client_secret": "test-secret", "gmail_refresh_token": "test-refresh"}.items():
        monkeypatch.setattr(email.settings, key, value)
    await email.send_action_email("reset@example.com", "Reset", "Reset", "vector://auth/reset-password?token=test")
    assert len(calls) == 2
