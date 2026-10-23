"""Normalize the complete Belarus education catalog.

Revision ID: 20261019_0005
Revises: 20261019_0004
"""

import sqlalchemy as sa
from alembic import op

revision = "20261019_0005"
down_revision = "20261019_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "education_institutions",
        sa.Column("source_updated_at", sa.String(40), nullable=False, server_default=""),
    )
    op.add_column("education_institutions", sa.Column("retrieved_at", sa.Date()))
    op.add_column(
        "education_institutions",
        sa.Column("identity_status", sa.String(100), nullable=False, server_default=""),
    )
    op.add_column(
        "education_specialties",
        sa.Column("education_level", sa.String(40), nullable=False, server_default=""),
    )

    op.create_table(
        "education_institution_specialties",
        sa.Column("institution_id", sa.String(160), nullable=False),
        sa.Column("specialty_id", sa.String(200), nullable=False),
        sa.Column("qualification", sa.Text(), nullable=False, server_default=""),
        sa.Column("source_label", sa.Text(), nullable=False, server_default=""),
        sa.Column("source_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("extraction_status", sa.String(100), nullable=False, server_default=""),
        sa.Column("source_details", sa.Text(), nullable=False, server_default=""),
        sa.Column("needs_verification", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(
            ["institution_id"], ["education_institutions.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["specialty_id"], ["education_specialties.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("institution_id", "specialty_id"),
    )
    op.create_index(
        "ix_education_institution_specialties_specialty_id",
        "education_institution_specialties",
        ["specialty_id"],
    )

    # Preserve the small legacy seed before removing its one-institution-only column.
    op.execute(
        """
        INSERT INTO education_institution_specialties
            (institution_id, specialty_id, qualification, source_url,
             needs_verification, is_active)
        SELECT institution_id, id, qualification, source_url,
               needs_verification, is_active
        FROM education_specialties
        ON CONFLICT (institution_id, specialty_id) DO NOTHING
        """
    )
    op.drop_index("ix_education_specialties_institution_id", table_name="education_specialties")
    op.drop_constraint(
        "education_specialties_institution_id_fkey",
        "education_specialties",
        type_="foreignkey",
    )
    op.drop_column("education_specialties", "institution_id")

    op.create_table(
        "education_source_records",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("institution_id", sa.String(160), nullable=False),
        sa.Column("source_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("source_updated_at", sa.String(40), nullable=False, server_default=""),
        sa.Column("fields", sa.JSON(), nullable=False),
        sa.Column("extracted_rows", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(
            ["institution_id"], ["education_institutions.id"], ondelete="CASCADE"
        ),
    )
    op.create_index(
        "ix_education_source_records_institution_id",
        "education_source_records",
        ["institution_id"],
    )
    op.create_table(
        "education_import_issues",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("institution_id", sa.String(160), nullable=False),
        sa.Column("error", sa.Text(), nullable=False, server_default=""),
        sa.Column("source_url", sa.String(1000), nullable=False, server_default=""),
        sa.ForeignKeyConstraint(
            ["institution_id"], ["education_institutions.id"], ondelete="CASCADE"
        ),
    )
    op.create_index(
        "ix_education_import_issues_institution_id",
        "education_import_issues",
        ["institution_id"],
    )
    op.create_table(
        "education_catalog_metadata",
        sa.Column("key", sa.String(120), primary_key=True),
        sa.Column("value", sa.JSON(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("education_catalog_metadata")
    op.drop_table("education_import_issues")
    op.drop_table("education_source_records")
    op.add_column(
        "education_specialties",
        sa.Column("institution_id", sa.String(160), nullable=True),
    )
    op.execute(
        """
        UPDATE education_specialties s
        SET institution_id = l.institution_id
        FROM (
            SELECT DISTINCT ON (specialty_id) specialty_id, institution_id
            FROM education_institution_specialties
            ORDER BY specialty_id, institution_id
        ) l
        WHERE s.id = l.specialty_id
        """
    )
    op.create_foreign_key(
        "education_specialties_institution_id_fkey",
        "education_specialties",
        "education_institutions",
        ["institution_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_education_specialties_institution_id",
        "education_specialties",
        ["institution_id"],
    )
    op.drop_table("education_institution_specialties")
    op.drop_column("education_specialties", "education_level")
    op.drop_column("education_institutions", "identity_status")
    op.drop_column("education_institutions", "retrieved_at")
    op.drop_column("education_institutions", "source_updated_at")
