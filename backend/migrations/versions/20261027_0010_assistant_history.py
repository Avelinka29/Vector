"""Persist AI assistant chat history.

Revision ID: 20261027_0010
Revises: 20261023_0009
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20261027_0010"
down_revision = "20261023_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "assistant_chat_messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("institution_ids", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("specialty_ids", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_assistant_chat_messages_user_id", "assistant_chat_messages", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_assistant_chat_messages_user_id", table_name="assistant_chat_messages")
    op.drop_table("assistant_chat_messages")
