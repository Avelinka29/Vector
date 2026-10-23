from pydantic import BaseModel, Field


class AssistantMessage(BaseModel):
    message: str = Field(min_length=2, max_length=2000)


class AssistantReply(BaseModel):
    answer: str
    institution_ids: list[str] = []
    specialty_ids: list[str] = []
    is_generated: bool = False
