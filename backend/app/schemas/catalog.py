from datetime import date

from pydantic import BaseModel, Field


class SpecialtyResponse(BaseModel):
    id: str
    institution_id: str
    name: str
    code: str
    education_level: str
    qualification: str
    study_forms: list[str]
    source_url: str
    last_verified_at: date | None
    needs_verification: bool

    faculty: str = ""
    duration: int | None = None
    budget_places: int | None = None
    paid_places: int | None = None
    description: str = ""
    model_config = {"from_attributes": True}


class InstitutionResponse(BaseModel):
    id: str
    name: str
    type: str
    locality: str
    region_id: str
    address: str
    website_url: str
    admissions_phone: str
    admissions_email: str
    admissions_url: str
    source_url: str
    last_verified_at: date | None
    needs_verification: bool

    education_levels: list[str] = Field(default_factory=list)
    description: str = ""
    model_config = {"from_attributes": True}
