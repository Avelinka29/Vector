from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class InstitutionProfile(Base):
    __tablename__ = "institution_profiles"

    organization_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), primary_key=True
    )
    catalog_institution_id: Mapped[str] = mapped_column(
        String(160), ForeignKey("education_institutions.id"), unique=True
    )
    institution_type: Mapped[str] = mapped_column(String(40), default="university")
    city: Mapped[str] = mapped_column(String(120), default="")
    region_id: Mapped[str] = mapped_column(String(40), default="")
    address: Mapped[str] = mapped_column(String(500), default="")
    website: Mapped[str] = mapped_column(String(1000), default="")
    phone: Mapped[str] = mapped_column(String(100), default="")
    email: Mapped[str] = mapped_column(String(320), default="")
    admissions_url: Mapped[str] = mapped_column(String(1000), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    published: Mapped[bool] = mapped_column(Boolean, default=False)
    revision: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class InstitutionProgram(Base):
    __tablename__ = "institution_programs"
    __table_args__ = (
        UniqueConstraint("organization_id", "code", "study_form", name="uq_institution_program_code_form"),
    )

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    organization_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), index=True
    )
    specialty_id: Mapped[str] = mapped_column(
        String(200), ForeignKey("education_specialties.id"), unique=True
    )
    name: Mapped[str] = mapped_column(String(500))
    code: Mapped[str] = mapped_column(String(80))
    faculty: Mapped[str] = mapped_column(String(250), default="")
    education_level: Mapped[str] = mapped_column(String(40), default="higher")
    qualification: Mapped[str] = mapped_column(String(500), default="")
    study_form: Mapped[str] = mapped_column(String(40))
    duration: Mapped[int] = mapped_column(Integer)
    budget_places: Mapped[int] = mapped_column(Integer, default=0)
    paid_places: Mapped[int] = mapped_column(Integer, default=0)
    description: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(20), default="draft")
    revision: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
