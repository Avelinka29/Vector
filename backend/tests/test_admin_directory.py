import httpx
import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.database import Base, get_session
from app.core.security import create_access_token
from app.main import app
from app.models.user import User
from app.models.organization import Organization, OrganizationMembership
from app.models.enums import UserRole, UserStatus, OrganizationType, VerificationStatus


@pytest.mark.asyncio
async def test_admin_directory_counts_search_and_access(tmp_path):
    engine = create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'directory.db'}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(lambda c: Base.metadata.create_all(c, tables=[
            User.__table__, Organization.__table__, OrganizationMembership.__table__]))
    async def sessions():
        async with factory() as session:
            yield session
    app.dependency_overrides[get_session] = sessions
    try:
        async with factory() as session:
            admin = User(email='admin@example.com', role=UserRole.ADMIN, status=UserStatus.ACTIVE, email_verified=True)
            owner = User(email='owner@example.com', role=UserRole.INSTITUTION, email_verified=True)
            applicant = User(email='applicant@example.com', full_name='Applicant', role=UserRole.APPLICANT, email_verified=False)
            session.add_all([admin, owner, applicant])
            await session.flush()
            session.add_all([
                Organization(name='Institute One', type=OrganizationType.INSTITUTION, created_by_id=owner.id),
                Organization(name='Institute Two', type=OrganizationType.INSTITUTION, created_by_id=owner.id, status=VerificationStatus.ACTIVE),
                Organization(name='Employer', type=OrganizationType.EMPLOYER, created_by_id=applicant.id),
            ])
            await session.commit()
            admin_headers={'Authorization': 'Bearer '+create_access_token(admin.id,'admin')[0]}
            applicant_headers={'Authorization': 'Bearer '+create_access_token(applicant.id,'applicant')[0]}
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test/api/v1') as client:
            for endpoint in ('/admin/overview', '/admin/participants'):
                assert (await client.get(endpoint)).status_code == 401
                assert (await client.get(endpoint, headers=applicant_headers)).status_code == 403
            result = await client.get('/admin/overview',headers=admin_headers)
            assert result.json() == dict(users=3,institutions=2,companies=1,pending=1)
            queue = await client.get('/organizations/admin',headers=admin_headers)
            assert sum(o['status'] in ('pending','needs_clarification') for o in queue.json()) == result.json()['pending']
            page = (await client.get('/admin/participants?category=universities&limit=1',headers=admin_headers)).json()
            following = (await client.get('/admin/participants?category=universities&limit=1&offset=1',headers=admin_headers)).json()
            assert page['has_more'] and not following['has_more']
            assert page['items'][0]['id'] != following['items'][0]['id']
            found = (await client.get('/admin/participants?category=universities&search=One',headers=admin_headers)).json()
            assert [r['name'] for r in found['items']] == ['Institute One']
            literal = (await client.get('/admin/participants',params={'search':'%'},headers=admin_headers)).json()
            assert literal['items'] == []
            people = (await client.get('/admin/participants',headers=admin_headers)).json()
            assert [r['email'] for r in people['items']] == ['applicant@example.com']
            assert not people['items'][0]['email_verified']
            companies = (await client.get('/admin/participants?category=companies',headers=admin_headers)).json()
            assert [r['name'] for r in companies['items']] == ['Employer']
            assert (await client.get('/admin/participants?limit=1000',headers=admin_headers)).status_code == 422
    finally:
        app.dependency_overrides.clear()
        await engine.dispose()
