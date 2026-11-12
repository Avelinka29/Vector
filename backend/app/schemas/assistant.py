from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class AssistantHistoryMessage(BaseModel):
    role: Literal["user", "assistant"]
    # Model replies can be longer than the user's 2,000-character prompt.
    content: str = Field(min_length=1, max_length=10000)


class AssistantMessage(BaseModel):
    message: str = Field(min_length=2, max_length=2000)
    history: list[AssistantHistoryMessage] = Field(default_factory=list, max_length=10)


class AssistantRelatedItem(BaseModel):
    id: str
    kind: Literal["institution", "specialty"]
    title: str
    subtitle: str = ""
    source_url: str = ""


class AssistantReply(BaseModel):
    answer: str
    institution_ids: list[str] = []
    specialty_ids: list[str] = []
    is_generated: bool = False
    related_items: list[AssistantRelatedItem] = []


class AssistantStoredMessage(BaseModel):
    id: UUID
    role: Literal["user", "assistant"]
    content: str
    institution_ids: list[str] = []
    specialty_ids: list[str] = []
    created_at: datetime
    related_items: list[AssistantRelatedItem] = []

    model_config = {"from_attributes": True}
