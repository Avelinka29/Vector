"""Add sourced catalog images.

Revision ID: 20261118_0016
Revises: 20261109_0015
"""
from alembic import op
import sqlalchemy as sa


revision = "20261118_0016"
down_revision = "20261109_0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for table in ("education_institutions", "education_specialties"):
        op.add_column(table, sa.Column("image_url", sa.String(length=1000), nullable=False, server_default=""))
        op.add_column(table, sa.Column("image_source_url", sa.String(length=1000), nullable=False, server_default=""))


def downgrade() -> None:
    for table in ("education_specialties", "education_institutions"):
        op.drop_column(table, "image_source_url")
        op.drop_column(table, "image_url")
