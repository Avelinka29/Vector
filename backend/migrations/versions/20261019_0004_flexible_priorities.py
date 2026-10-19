"""Allow atomic client-side priority reordering.

Revision ID: 20261019_0004
Revises: 20261019_0003
"""

from alembic import op

revision = "20261019_0004"
down_revision = "20261019_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint("applications_applicant_id_priority_key", "applications", type_="unique")


def downgrade() -> None:
    op.create_unique_constraint(
        "applications_applicant_id_priority_key",
        "applications",
        ["applicant_id", "priority"],
    )
