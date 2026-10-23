from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, HttpUrl


class InstitutionProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    city: str = Field(min_length=1, max_length=120)
    region_id: str = Field(default="", max_length=40)
    address: str = Field(min_length=1, max_length=500)
    website: HttpUrl | None = None
    phone: str = Field(min_length=1, max_length=100)
    email: EmailStr
    admissions_url: HttpUrl | None = None
    description: str = Field(default="", max_length=5000)
    institution_type: Literal["university", "academy", "institute", "college", "other"] = "university"
    published: bool = False
    revision: int = Field(ge=0)


class InstitutionProgramUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=2, max_length=500)
    code: str = Field(min_length=1, max_length=80)
    faculty: str = Field(default="", max_length=250)
    education_level: Literal["higher", "master", "secondary_special", "vocational"] = "higher"
    qualification: str = Field(default="", max_length=500)
    study_form: Literal["full_time", "part_time", "distance"] = "full_time"
    duration: int = Field(ge=1, le=8)
    budget_places: int = Field(ge=0, le=10000)
    paid_places: int = Field(ge=0, le=10000)
    description: str = Field(default="", max_length=10000)
    status: Literal["draft", "published", "archived"] = "draft"
    revision: int = Field(ge=0)
