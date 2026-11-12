"""Persist assistant recommendation cards."""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20261027_0013"
down_revision = "20261027_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "assistant_chat_messages",
        sa.Column("related_items", postgresql.JSONB(), nullable=False, server_default="[]"),
    )


def downgrade() -> None:
    op.drop_column("assistant_chat_messages", "related_items")
