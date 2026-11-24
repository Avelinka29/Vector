import asyncio
import logging
from pathlib import Path
from contextlib import asynccontextmanager, suppress

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api.router import api_router
from app.core.config import settings
from app.core.database import engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    Path(settings.catalog_image_directory).mkdir(parents=True, exist_ok=True)
    if settings.environment == "production" and settings.jwt_secret.startswith("development-"):
        raise RuntimeError("Set a secure VECTOR_JWT_SECRET before running in production")
    async def mail_worker():
        from app.services.institution_email import deliver_pending
        while True:
            try:
                await deliver_pending()
            except Exception:
                logging.getLogger(__name__).warning("Email queue temporarily unavailable")
            await asyncio.sleep(15)
    async def push_worker():
        from app.services.push import deliver_pending_pushes
        while True:
            try:
                await deliver_pending_pushes()
            except Exception:
                logging.getLogger(__name__).warning("Push queue temporarily unavailable")
            await asyncio.sleep(10)
    worker = asyncio.create_task(mail_worker())
    push_task = asyncio.create_task(push_worker())
    try:
        yield
    finally:
        worker.cancel()
        push_task.cancel()
        with suppress(asyncio.CancelledError):
            await worker
        with suppress(asyncio.CancelledError):
            await push_task


app = FastAPI(
    title="VECTOR API",
    version="0.1.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount(
    "/catalog-images",
    StaticFiles(directory=settings.catalog_image_directory, check_dir=False),
    name="catalog-images",
)
app.include_router(api_router)


@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready", tags=["system"])
async def readiness() -> dict[str, str]:
    try:
        async with engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
        image_directory = Path(settings.catalog_image_directory)
        image_directory.mkdir(parents=True, exist_ok=True)
        if not image_directory.is_dir():
            raise RuntimeError("Catalog image storage is unavailable")
    except Exception as error:
        logging.getLogger(__name__).error("Readiness check failed: %s", type(error).__name__)
        raise HTTPException(status_code=503, detail="Service dependencies are unavailable") from error
    return {"status": "ready", "database": "ok", "catalog_storage": "ok"}
