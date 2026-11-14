from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class VacancyCreate(BaseModel):
    title: str = Field(min_length=2, max_length=250)
    description: str = Field(default="", max_length=10000)
    city: str = Field(default="", max_length=120)
    employment_type: str = Field(default="", max_length=80)
    salary_from: int | None = Field(default=None, ge=0)
    salary_to: int | None = Field(default=None, ge=0)
    status: str = Field(default="draft", pattern="^(draft|published|archived)$")
    expires_at: date | None = None

    @model_validator(mode="after")
    def salary_range(self):
        if self.salary_from is not None and self.salary_to is not None and self.salary_from > self.salary_to:
            raise ValueError("Минимальная зарплата не может быть выше максимальной")
        return self


class VacancyResponse(BaseModel):
    id: UUID
    organization_id: UUID
    title: str
    description: str
    city: str
    employment_type: str
    salary_from: int | None
    salary_to: int | None
    status: str
    expires_at: date | None
    created_at: datetime
    updated_at: datetime
    responses_count: int = 0

    model_config = {"from_attributes": True}


class VacancyApplicationCreate(BaseModel):
    cover_letter: str = Field(default="", max_length=5000)


class VacancyApplicationUpdate(BaseModel):
    status: str = Field(pattern="^(new|reviewing|invited|rejected)$")
    employer_comment: str = Field(default="", max_length=5000)


class VacancyApplicationResponse(BaseModel):
    id: UUID
    vacancy_id: UUID
    applicant_id: UUID
    applicant_email: str = ""
    vacancy_title: str = ""
    cover_letter: str
    status: str
    employer_comment: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MemberResponse(BaseModel):
    membership_id: UUID
    user_id: UUID
    email: str
    role: str
    created_at: datetime


class MemberInvite(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    role: str = Field(default="member", pattern="^(manager|member)$")


class ApplicationCommentCreate(BaseModel):
    text: str = Field(min_length=1, max_length=5000)
    is_internal: bool = False


class ApplicationCommentResponse(BaseModel):
    id: UUID
    application_id: UUID
    author_id: UUID
    text: str
    is_internal: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class ApplicationDocumentResponse(BaseModel):
    id: UUID
    application_id: UUID
    kind: str
    original_name: str
    content_type: str
    size_bytes: int
    created_at: datetime

    model_config = {"from_attributes": True}
