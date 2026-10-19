"""Account actions, profiles and applications.

Revision ID: 20261019_0003
Revises: 20261019_0002
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20261019_0003"
down_revision = "20261019_0002"
branch_labels = None
depends_on = None

action_token_purpose = postgresql.ENUM(
    "verify_email", "reset_password", name="action_token_purpose"
)
application_status = postgresql.ENUM(
    "draft",
    "submitted",
    "documentsReview",
    "accepted",
    "rejected",
    name="application_status",
)


def upgrade() -> None:
    op.create_table(
        "action_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("purpose", action_token_purpose, nullable=False),
        sa.Column("digest", sa.String(64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_action_tokens_digest", "action_tokens", ["digest"], unique=True)
    op.create_index("ix_action_tokens_user_id", "action_tokens", ["user_id"])

    op.create_table(
        "applicant_profiles",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("schema_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("completion_percentage", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("data", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )

    op.create_table(
        "applications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("applicant_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("institution_id", sa.String(160), nullable=False),
        sa.Column("specialty_id", sa.String(200), nullable=False),
        sa.Column("institution_name", sa.String(500), nullable=False),
        sa.Column("specialty_name", sa.String(500), nullable=False),
        sa.Column("study_form", sa.String(100), nullable=False, server_default=""),
        sa.Column("funding_type", sa.String(50), nullable=False, server_default="budget"),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("status", application_status, nullable=False, server_default="submitted"),
        sa.Column("history", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["applicant_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["institution_id"], ["education_institutions.id"]),
        sa.ForeignKeyConstraint(["specialty_id"], ["education_specialties.id"]),
        sa.UniqueConstraint("applicant_id", "priority"),
    )
    op.create_index("ix_applications_applicant_id", "applications", ["applicant_id"])
    op.create_index("ix_applications_institution_id", "applications", ["institution_id"])
    op.create_index("ix_applications_specialty_id", "applications", ["specialty_id"])


def downgrade() -> None:
    op.drop_table("applications")
    op.drop_table("applicant_profiles")
    op.drop_table("action_tokens")
    bind = op.get_bind()
    application_status.drop(bind, checkfirst=True)
    action_token_purpose.drop(bind, checkfirst=True)
