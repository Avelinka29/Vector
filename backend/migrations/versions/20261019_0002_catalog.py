"""Education catalog.

Revision ID: 20261019_0002
Revises: 20261019_0001
"""

import sqlalchemy as sa
from alembic import op

revision = "20261019_0002"
down_revision = "20261019_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "education_institutions",
        sa.Column("id", sa.String(160), primary_key=True),
        sa.Column("name", sa.String(500), nullable=False),
        sa.Column("type", sa.String(80), nullable=False, server_default=""),
        sa.Column("locality", sa.String(160), nullable=False, server_default=""),
        sa.Column("region_id", sa.String(40), nullable=False, server_default=""),
        sa.Column("address", sa.String(500), nullable=False, server_default=""),
        sa.Column("website_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("admissions_phone", sa.String(100), nullable=False, server_default=""),
        sa.Column("admissions_email", sa.String(320), nullable=False, server_default=""),
        sa.Column("admissions_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("source_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("last_verified_at", sa.Date()),
        sa.Column("needs_verification", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_education_institutions_name", "education_institutions", ["name"])
    op.create_index("ix_education_institutions_locality", "education_institutions", ["locality"])
    op.create_table(
        "education_specialties",
        sa.Column("id", sa.String(200), primary_key=True),
        sa.Column("institution_id", sa.String(160), nullable=False),
        sa.Column("name", sa.String(500), nullable=False),
        sa.Column("code", sa.String(80), nullable=False, server_default=""),
        sa.Column("qualification", sa.Text(), nullable=False, server_default=""),
        sa.Column("study_forms", sa.JSON(), nullable=False),
        sa.Column("source_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("last_verified_at", sa.Date()),
        sa.Column("needs_verification", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(
            ["institution_id"], ["education_institutions.id"], ondelete="CASCADE"
        ),
    )
    op.create_index(
        "ix_education_specialties_institution_id",
        "education_specialties",
        ["institution_id"],
    )
    op.create_index("ix_education_specialties_name", "education_specialties", ["name"])


def downgrade() -> None:
    op.drop_table("education_specialties")
    op.drop_table("education_institutions")
