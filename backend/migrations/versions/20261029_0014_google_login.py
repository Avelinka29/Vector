"""Associate Google accounts by their stable subject identifier."""

import sqlalchemy as sa
from alembic import op

revision = "20261029_0014"
down_revision = "20261027_0013"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("google_subject", sa.String(255), nullable=True))
    op.create_unique_constraint("uq_users_google_subject", "users", ["google_subject"])


def downgrade():
    op.drop_constraint("uq_users_google_subject", "users", type_="unique")
    op.drop_column("users", "google_subject")
