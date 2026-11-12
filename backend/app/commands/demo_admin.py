"""Explicitly provision the local defense administrator; never run in production."""
import asyncio

from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionFactory
from app.core.security import hash_password
from app.models.enums import UserRole, UserStatus
from app.models.user import User

DEMO_ADMIN_EMAIL = "admin@vector.example"


async def provision_demo_admin(session):
    if settings.environment != "development":
        raise RuntimeError("Demo administrator is available only in development")
    user = await session.scalar(select(User).where(User.email == DEMO_ADMIN_EMAIL))
    if user is not None:
        if user.role != UserRole.ADMIN:
            raise RuntimeError("Demo email is already occupied by a non-admin account")
        return user  # Never reset an existing password or unblock an account.
    user = User(email=DEMO_ADMIN_EMAIL, full_name="Администратор VECTOR",
                password_hash=hash_password("admin"), role=UserRole.ADMIN,
                status=UserStatus.ACTIVE, email_verified=True)
    session.add(user)
    await session.commit()
    return user


async def main():
    async with SessionFactory() as session:
        await provision_demo_admin(session)
    print("Local demo administrator is ready")


if __name__ == "__main__":
    asyncio.run(main())
