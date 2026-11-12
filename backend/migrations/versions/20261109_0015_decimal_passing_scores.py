"""Preserve fractional official admission scores without rounding."""
import sqlalchemy as sa
from alembic import op

revision = '20261109_0015'
down_revision = '20261029_0014'
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column('education_passing_scores', 'score', existing_type=sa.Integer(),
                    type_=sa.Numeric(6, 2), existing_nullable=False,
                    postgresql_using='score::numeric(6,2)')


def downgrade():
    connection = op.get_bind()
    if connection.execute(sa.text('SELECT 1 FROM education_passing_scores WHERE score <> trunc(score) LIMIT 1')).first():
        raise RuntimeError('Cannot downgrade: fractional scores would be lost')
    op.alter_column('education_passing_scores', 'score', existing_type=sa.Numeric(6, 2),
                    type_=sa.Integer(), existing_nullable=False, postgresql_using='score::integer')
