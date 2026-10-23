"""Persist applicant profile wizard progress.

Revision ID: 20261021_0006
Revises: 20261019_0005
"""

import sqlalchemy as sa
from alembic import op

revision = "20261021_0006"
down_revision = "20261019_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "applicant_profiles",
        sa.Column("current_step", sa.Integer(), nullable=False, server_default="1"),
    )


def downgrade() -> None:
    op.drop_column("applicant_profiles", "current_step")
