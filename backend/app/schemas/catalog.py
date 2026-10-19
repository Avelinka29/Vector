from datetime import date

from pydantic import BaseModel


class SpecialtyResponse(BaseModel):
    id: str
    institution_id: str
    name: str
    code: str
    qualification: str
    study_forms: list[str]
    source_url: str
    last_verified_at: date | None
    needs_verification: bool

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

    model_config = {"from_attributes": True}
