"""Add employer workspace, application files and notification outbox."""

import sqlalchemy as sa
from alembic import op

revision = "20261027_0012"
down_revision = "20261027_0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("applications", sa.Column("submission_deadline", sa.Date(), nullable=True))
    op.create_table(
        "vacancies",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("organization_id", sa.UUID(), sa.ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(250), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("city", sa.String(120), nullable=False, server_default=""),
        sa.Column("employment_type", sa.String(80), nullable=False, server_default=""),
        sa.Column("salary_from", sa.Integer(), nullable=True),
        sa.Column("salary_to", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(32), nullable=False, server_default="draft"),
        sa.Column("expires_at", sa.Date(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_vacancies_organization_id", "vacancies", ["organization_id"])
    op.create_table(
        "vacancy_responses",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("vacancy_id", sa.UUID(), sa.ForeignKey("vacancies.id", ondelete="CASCADE"), nullable=False),
        sa.Column("applicant_id", sa.UUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("cover_letter", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", sa.String(32), nullable=False, server_default="new"),
        sa.Column("employer_comment", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("vacancy_id", "applicant_id", name="vacancy_response_identity_key"),
    )
    op.create_index("ix_vacancy_responses_vacancy_id", "vacancy_responses", ["vacancy_id"])
    op.create_index("ix_vacancy_responses_applicant_id", "vacancy_responses", ["applicant_id"])
    op.create_table(
        "application_documents",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("application_id", sa.UUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), nullable=False),
        sa.Column("uploaded_by_id", sa.UUID(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("kind", sa.String(80), nullable=False, server_default="other"),
        sa.Column("original_name", sa.String(255), nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False, unique=True),
        sa.Column("content_type", sa.String(120), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_application_documents_application_id", "application_documents", ["application_id"])
    op.create_table(
        "application_comments",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("application_id", sa.UUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), nullable=False),
        sa.Column("author_id", sa.UUID(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("is_internal", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_application_comments_application_id", "application_comments", ["application_id"])
    op.create_table(
        "notification_outbox",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("body", sa.String(1000), nullable=False),
        sa.Column("event_type", sa.String(80), nullable=False),
        sa.Column("entity_id", sa.String(160), nullable=False, server_default=""),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("error", sa.String(1000), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_notification_outbox_user_id", "notification_outbox", ["user_id"])
    op.create_index("ix_notification_outbox_event_type", "notification_outbox", ["event_type"])


def downgrade() -> None:
    op.drop_table("notification_outbox")
    op.drop_table("application_comments")
    op.drop_table("application_documents")
    op.drop_table("vacancy_responses")
    op.drop_table("vacancies")
    op.drop_column("applications", "submission_deadline")
