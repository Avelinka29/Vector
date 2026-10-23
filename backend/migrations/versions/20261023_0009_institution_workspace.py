"""Institution-owned profiles and programs, projected into the mobile catalog."""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20261023_0009"
down_revision = "20261022_0008"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "institution_profiles",
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("catalog_institution_id", sa.String(160), sa.ForeignKey("education_institutions.id"), nullable=False, unique=True),
        sa.Column("institution_type", sa.String(40), nullable=False, server_default="university"),
        sa.Column("city", sa.String(120), nullable=False, server_default=""),
        sa.Column("region_id", sa.String(40), nullable=False, server_default=""),
        sa.Column("address", sa.String(500), nullable=False, server_default=""),
        sa.Column("website", sa.String(1000), nullable=False, server_default=""),
        sa.Column("phone", sa.String(100), nullable=False, server_default=""),
        sa.Column("email", sa.String(320), nullable=False, server_default=""),
        sa.Column("admissions_url", sa.String(1000), nullable=False, server_default=""),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("published", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("revision", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_table(
        "institution_programs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False),
        sa.Column("specialty_id", sa.String(200), sa.ForeignKey("education_specialties.id"), nullable=False, unique=True),
        sa.Column("name", sa.String(500), nullable=False),
        sa.Column("code", sa.String(80), nullable=False),
        sa.Column("faculty", sa.String(250), nullable=False, server_default=""),
        sa.Column("education_level", sa.String(40), nullable=False, server_default="higher"),
        sa.Column("qualification", sa.String(500), nullable=False, server_default=""),
        sa.Column("study_form", sa.String(40), nullable=False),
        sa.Column("duration", sa.Integer(), nullable=False),
        sa.Column("budget_places", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("paid_places", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("revision", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("organization_id", "code", "study_form", name="uq_institution_program_code_form"),
    )
    op.create_index("ix_institution_programs_organization_id", "institution_programs", ["organization_id"])


def downgrade():
    op.drop_table("institution_programs")
    op.drop_table("institution_profiles")
