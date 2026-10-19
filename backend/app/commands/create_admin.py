import asyncio
import getpass

from sqlalchemy import select

from app.core.database import SessionFactory
from app.core.security import hash_password
from app.models.enums import UserRole, UserStatus
from app.models.user import User
from app.services.auth import normalized_email


async def create_admin() -> None:
    email = normalized_email(input("Admin email: "))
    full_name = input("Full name: ").strip()
    password = getpass.getpass("Password: ")
    if len(password) < 8:
        raise ValueError("Password must contain at least 8 characters")
    async with SessionFactory() as session:
        existing = await session.scalar(select(User).where(User.email == email))
        if existing:
            existing.role = UserRole.ADMIN
            existing.status = UserStatus.ACTIVE
            existing.password_hash = hash_password(password)
            existing.full_name = full_name or existing.full_name
        else:
            session.add(
                User(
                    email=email,
                    full_name=full_name,
                    password_hash=hash_password(password),
                    role=UserRole.ADMIN,
                    status=UserStatus.ACTIVE,
                    email_verified=True,
                )
            )
        await session.commit()
    print("Administrator account is ready")


if __name__ == "__main__":
    asyncio.run(create_admin())
