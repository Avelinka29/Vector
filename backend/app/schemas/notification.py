from pydantic import BaseModel, Field


class DeviceTokenUpsert(BaseModel):
    token: str = Field(min_length=16, max_length=512)
    platform: str = Field(default="ios", max_length=32)


class DeviceTokenResponse(BaseModel):
    token: str
    platform: str

    model_config = {"from_attributes": True}
