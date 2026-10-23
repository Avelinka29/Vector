import httpx
import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from app.core.database import Base, get_session
from app.core.security import hash_password
from app.main import app
from app.models import User, Organization, OrganizationMembership
from app.models.enums import UserRole, UserStatus, OrganizationType, VerificationStatus, MembershipRole

@pytest.mark.asyncio
async def test_publication_and_isolation(tmp_path):
    engine=create_async_engine(f"sqlite+aiosqlite:///{tmp_path / 'workspace.db'}")
    factory=async_sessionmaker(engine,expire_on_commit=False)
    async with engine.begin() as c: await c.run_sync(Base.metadata.create_all)
    async def sessions():
        async with factory() as s: yield s
    app.dependency_overrides[get_session]=sessions
    try:
        async with factory() as s:
            for i in range(2):
                u=User(email=f'u{i}@example.com',full_name='Owner',role=UserRole.INSTITUTION,status=UserStatus.ACTIVE,email_verified=True,password_hash=hash_password('password-long-test'))
                s.add(u);await s.flush()
                o=Organization(type=OrganizationType.INSTITUTION,name='University',created_by_id=u.id,status=VerificationStatus.ACTIVE)
                s.add(o);await s.flush()
                s.add(OrganizationMembership(user_id=u.id,organization_id=o.id,role=MembershipRole.OWNER))
            await s.commit()
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url='http://test/api/v1') as c:
            h=[]
            for i in range(2):
                r=await c.post('/auth/login',json={'email':f'u{i}@example.com','password':'password-long-test'})
                h.append({'Authorization':'Bearer '+r.json()['access_token']})
            root='/institutions/workspace'
            initial=await c.get(root,headers=h[0]);assert initial.status_code==200,initial.text
            assert not initial.json()['profile']['published']
            profile=dict(city='Минск',address='Адрес 1',phone='123456789',email='admissions@example.com',published=True,revision=0)
            assert (await c.put(root+'/profile',headers=h[0],json={**profile,'name':'Hijack'})).status_code==422
            r=await c.put(root+'/profile',headers=h[0],json=profile);assert r.status_code==200,r.text
            assert (await c.put(root+'/profile',headers=h[0],json=profile)).status_code==409
            r=await c.get('/catalog/institutions');assert r.status_code==200,r.text
            assert len(r.json())==1
            p=dict(name='Информатика',code='6-05',duration=4,budget_places=30,paid_places=20,revision=0,status='draft')
            r=await c.post(root+'/programs',headers=h[0],json=p);assert r.status_code==201,r.text
            saved=r.json();pid=saved['id']
            assert (await c.get('/catalog/specialties')).json()==[]
            p.update(revision=1,status='published')
            assert (await c.put(root+'/programs/'+pid,headers=h[1],json=p)).status_code==404
            r=await c.put(root+'/programs/'+pid,headers=h[0],json=p);assert r.status_code==200,r.text
            assert (await c.put(root+'/programs/'+pid,headers=h[0],json=p)).status_code==409
            r=await c.get('/catalog/specialties');assert r.status_code==200,r.text
            assert r.json()[0]['budget_places']==30 and r.json()[0]['id']==saved['specialty_id']
            assert (await c.post(root+'/programs',headers=h[0],json={**p,'revision':0})).status_code==409
            r=await c.put(root+'/programs/'+pid,headers=h[0],json={**p,'revision':2,'status':'archived'});assert r.status_code==200,r.text
            assert (await c.get('/catalog/specialties')).json()==[]
            assert (await c.get(root,headers=h[0])).json()['programs'][0]['status']=='archived'
            assert (await c.put(root+'/profile',headers=h[0],json={**profile,'revision':1,'published':False})).status_code==200
            assert (await c.get('/catalog/institutions')).json()==[]
    finally:
        app.dependency_overrides.clear();await engine.dispose()
