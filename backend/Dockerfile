FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY pyproject.toml alembic.ini ./
RUN pip install --no-cache-dir \
    "alembic>=1.14,<2" \
    "asyncpg>=0.30,<1" \
    "email-validator>=2.2,<3" \
    "fastapi>=0.115,<1" \
    "httpx>=0.28,<1" \
    "pwdlib[argon2]>=0.2,<1" \
    "pydantic-settings>=2.7,<3" \
    "pyjwt[crypto]>=2.10,<3" \
    "python-multipart>=0.0.20,<1" \
    "sqlalchemy[asyncio]>=2.0.36,<3" \
    "uvicorn[standard]>=0.34,<1" \
    "aiosmtplib>=3.0,<5"
COPY app ./app
COPY migrations ./migrations
RUN pip install --no-cache-dir --no-deps .

EXPOSE 8000
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
