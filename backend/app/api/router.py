from fastapi import APIRouter

from app.api.routes import applications, auth, catalog, organizations, profile

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(catalog.router)
api_router.include_router(organizations.router)
api_router.include_router(profile.router)
api_router.include_router(applications.router)
