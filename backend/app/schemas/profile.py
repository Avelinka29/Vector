from datetime import datetime

from pydantic import BaseModel, Field


class ProfileUpsert(BaseModel):
    schema_version: int = Field(default=1, ge=1)
    completion_percentage: int = Field(default=0, ge=0, le=100)
    data: dict


class ProfileResponse(ProfileUpsert):
    updated_at: datetime

    model_config = {"from_attributes": True}
