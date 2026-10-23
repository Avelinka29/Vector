from datetime import datetime

from pydantic import BaseModel, Field


class ProfileUpsert(BaseModel):
    schema_version: int = Field(default=1, ge=1)
    completion_percentage: int = Field(default=0, ge=0, le=100)
    data: dict


class ProfileProgressUpdate(BaseModel):
    current_step: int = Field(ge=1, le=10)


class ProfileResponse(ProfileUpsert):
    current_step: int
    updated_at: datetime

    model_config = {"from_attributes": True}
