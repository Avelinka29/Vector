from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    id: UUID
    title: str
    body: str
    event_type: str
    entity_id: str
    is_read: bool
    delivered_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}
