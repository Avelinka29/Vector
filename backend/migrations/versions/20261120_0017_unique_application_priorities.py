"""Guarantee one priority per applicant.

Revision ID: 20261120_0017
Revises: 20261118_0016
"""
from alembic import op


revision = "20261120_0017"
down_revision = "20261118_0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        WITH ranked AS (
            SELECT id, row_number() OVER (
                PARTITION BY applicant_id ORDER BY priority, created_at, id
            ) AS normalized_priority
            FROM applications
        )
        UPDATE applications
        SET priority = ranked.normalized_priority
        FROM ranked
        WHERE applications.id = ranked.id
    """)
    op.create_unique_constraint(
        "applications_applicant_priority_key",
        "applications",
        ["applicant_id", "priority"],
    )


def downgrade() -> None:
    op.drop_constraint("applications_applicant_priority_key", "applications", type_="unique")
