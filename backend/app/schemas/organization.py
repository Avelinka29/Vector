from uuid import UUID

from pydantic import BaseModel, Field, HttpUrl

from app.models.enums import OrganizationType, VerificationStatus


class OrganizationCreate(BaseModel):
    type: OrganizationType
    name: str = Field(min_length=2, max_length=250)
    legal_name: str = Field(default="", max_length=300)
    tax_id: str = Field(default="", max_length=32)
    city: str = Field(default="", max_length=120)
    website: HttpUrl | None = None
    description: str = Field(default="", max_length=5000)


class OrganizationStatusUpdate(BaseModel):
    status: VerificationStatus


class OrganizationResponse(BaseModel):
    id: UUID
    type: OrganizationType
    name: str
    legal_name: str
    tax_id: str
    city: str
    website: str
    description: str
    status: VerificationStatus
    created_by_id: UUID

    model_config = {"from_attributes": True}
