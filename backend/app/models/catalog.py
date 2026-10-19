from datetime import date, datetime

from sqlalchemy import JSON, Boolean, Date, DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class EducationInstitution(Base):
    __tablename__ = "education_institutions"

    id: Mapped[str] = mapped_column(String(160), primary_key=True)
    name: Mapped[str] = mapped_column(String(500), index=True)
    type: Mapped[str] = mapped_column(String(80), default="")
    locality: Mapped[str] = mapped_column(String(160), default="", index=True)
    region_id: Mapped[str] = mapped_column(String(40), default="")
    address: Mapped[str] = mapped_column(String(500), default="")
    website_url: Mapped[str] = mapped_column(String(1000), default="")
    admissions_phone: Mapped[str] = mapped_column(String(100), default="")
    admissions_email: Mapped[str] = mapped_column(String(320), default="")
    admissions_url: Mapped[str] = mapped_column(String(1000), default="")
    source_url: Mapped[str] = mapped_column(String(1000), default="")
    last_verified_at: Mapped[date | None] = mapped_column(Date)
    needs_verification: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    specialties = relationship(
        "EducationSpecialty", back_populates="institution", cascade="all, delete-orphan"
    )


class EducationSpecialty(Base):
    __tablename__ = "education_specialties"

    id: Mapped[str] = mapped_column(String(200), primary_key=True)
    institution_id: Mapped[str] = mapped_column(
        String(160), ForeignKey("education_institutions.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(500), index=True)
    code: Mapped[str] = mapped_column(String(80), default="")
    qualification: Mapped[str] = mapped_column(Text, default="")
    study_forms: Mapped[list[str]] = mapped_column(JSON, default=list)
    source_url: Mapped[str] = mapped_column(String(1000), default="")
    last_verified_at: Mapped[date | None] = mapped_column(Date)
    needs_verification: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    institution = relationship("EducationInstitution", back_populates="specialties")
