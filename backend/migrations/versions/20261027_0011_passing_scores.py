"""Add verified passing scores by institution, specialty and year."""

import sqlalchemy as sa
from alembic import op

revision = "20261027_0011"
down_revision = "20261027_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "education_passing_scores",
        sa.Column("id", sa.String(240), primary_key=True),
        sa.Column("institution_id", sa.String(160), sa.ForeignKey("education_institutions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("specialty_id", sa.String(200), sa.ForeignKey("education_specialties.id", ondelete="CASCADE"), nullable=False),
        sa.Column("admission_year", sa.Integer(), nullable=False),
        sa.Column("study_form", sa.String(100), nullable=False, server_default=""),
        sa.Column("funding_type", sa.String(50), nullable=False, server_default="budget"),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("source_url", sa.String(1000), nullable=False),
        sa.Column("verified_at", sa.Date(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("institution_id", "specialty_id", "admission_year", "study_form", "funding_type", name="education_passing_scores_identity_key"),
    )
    op.create_index("ix_education_passing_scores_institution_id", "education_passing_scores", ["institution_id"])
    op.create_index("ix_education_passing_scores_specialty_id", "education_passing_scores", ["specialty_id"])


def downgrade() -> None:
    op.drop_table("education_passing_scores")
