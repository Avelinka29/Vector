from datetime import datetime
from enum import StrEnum
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ApplicationStatus(StrEnum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    DOCUMENTS_REVIEW = "documentsReview"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class Application(Base):
    __tablename__ = "applications"

    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    applicant_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    institution_id: Mapped[str] = mapped_column(
        String(160), ForeignKey("education_institutions.id"), index=True
    )
    specialty_id: Mapped[str] = mapped_column(
        String(200), ForeignKey("education_specialties.id"), index=True
    )
    institution_name: Mapped[str] = mapped_column(String(500))
    specialty_name: Mapped[str] = mapped_column(String(500))
    study_form: Mapped[str] = mapped_column(String(100), default="")
    funding_type: Mapped[str] = mapped_column(String(50), default="budget")
    priority: Mapped[int] = mapped_column(Integer)
    status: Mapped[ApplicationStatus] = mapped_column(
        Enum(
            ApplicationStatus,
            name="application_status",
            values_callable=lambda enum: [item.value for item in enum],
        ),
        default=ApplicationStatus.SUBMITTED,
    )
    history: Mapped[list[dict]] = mapped_column(JSONB, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
