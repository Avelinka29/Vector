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
    source_updated_at: Mapped[str] = mapped_column(String(40), default="")
    retrieved_at: Mapped[date | None] = mapped_column(Date)
    identity_status: Mapped[str] = mapped_column(String(100), default="")
    last_verified_at: Mapped[date | None] = mapped_column(Date)
    needs_verification: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    specialty_links = relationship(
        "EducationInstitutionSpecialty",
        back_populates="institution",
        cascade="all, delete-orphan",
    )


class EducationSpecialty(Base):
    __tablename__ = "education_specialties"

    id: Mapped[str] = mapped_column(String(200), primary_key=True)
    name: Mapped[str] = mapped_column(String(500), index=True)
    code: Mapped[str] = mapped_column(String(80), default="")
    education_level: Mapped[str] = mapped_column(String(40), default="")
    qualification: Mapped[str] = mapped_column(Text, default="")
    study_forms: Mapped[list[str]] = mapped_column(JSON, default=list)
    source_url: Mapped[str] = mapped_column(String(1000), default="")
    last_verified_at: Mapped[date | None] = mapped_column(Date)
    needs_verification: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    institution_links = relationship(
        "EducationInstitutionSpecialty",
        back_populates="specialty",
        cascade="all, delete-orphan",
    )


class EducationInstitutionSpecialty(Base):
    __tablename__ = "education_institution_specialties"

    institution_id: Mapped[str] = mapped_column(
        String(160),
        ForeignKey("education_institutions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    specialty_id: Mapped[str] = mapped_column(
        String(200),
        ForeignKey("education_specialties.id", ondelete="CASCADE"),
        primary_key=True,
    )
    qualification: Mapped[str] = mapped_column(Text, default="")
    source_label: Mapped[str] = mapped_column(Text, default="")
    source_url: Mapped[str] = mapped_column(String(1000), default="")
    extraction_status: Mapped[str] = mapped_column(String(100), default="")
    source_details: Mapped[str] = mapped_column(Text, default="")
    needs_verification: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    institution = relationship("EducationInstitution", back_populates="specialty_links")
    specialty = relationship("EducationSpecialty", back_populates="institution_links")


class EducationSourceRecord(Base):
    __tablename__ = "education_source_records"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    institution_id: Mapped[str] = mapped_column(
        String(160), ForeignKey("education_institutions.id", ondelete="CASCADE"), index=True
    )
    source_url: Mapped[str] = mapped_column(String(1000), default="")
    source_updated_at: Mapped[str] = mapped_column(String(40), default="")
    fields: Mapped[dict] = mapped_column(JSON, default=dict)
    extracted_rows: Mapped[list] = mapped_column(JSON, default=list)


class EducationImportIssue(Base):
    __tablename__ = "education_import_issues"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    institution_id: Mapped[str] = mapped_column(
        String(160), ForeignKey("education_institutions.id", ondelete="CASCADE"), index=True
    )
    error: Mapped[str] = mapped_column(Text, default="")
    source_url: Mapped[str] = mapped_column(String(1000), default="")


class EducationCatalogMetadata(Base):
    __tablename__ = "education_catalog_metadata"

    key: Mapped[str] = mapped_column(String(120), primary_key=True)
    value: Mapped[object] = mapped_column(JSON)
