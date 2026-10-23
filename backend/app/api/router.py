from fastapi import APIRouter

from app.api.routes import applications, assistant, auth, catalog, notifications, organizations, profile
from app.api.routes import institution_registration, institution_workspace

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(catalog.router)
api_router.include_router(institution_registration.router)
api_router.include_router(institution_workspace.router)
api_router.include_router(organizations.router)
api_router.include_router(profile.router)
api_router.include_router(applications.router)
api_router.include_router(notifications.router)
api_router.include_router(assistant.router)
