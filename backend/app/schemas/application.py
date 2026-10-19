from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.application import ApplicationStatus


class ApplicationCreate(BaseModel):
    id: UUID | None = None
    institution_id: str = Field(min_length=1, max_length=160)
    specialty_id: str = Field(min_length=1, max_length=200)
    study_form: str = Field(default="", max_length=100)
    funding_type: str = Field(default="budget", max_length=50)
    priority: int = Field(ge=1, le=20)
    status: ApplicationStatus = ApplicationStatus.SUBMITTED


class ApplicationPriorityUpdate(BaseModel):
    priority: int = Field(ge=1, le=20)


class ApplicationStatusUpdate(BaseModel):
    status: ApplicationStatus
    comment: str | None = Field(default=None, max_length=2000)


class ApplicationResponse(BaseModel):
    id: UUID
    applicant_id: UUID
    institution_id: str
    specialty_id: str
    institution_name: str
    specialty_name: str
    study_form: str
    funding_type: str
    priority: int
    status: ApplicationStatus
    history: list[dict]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
