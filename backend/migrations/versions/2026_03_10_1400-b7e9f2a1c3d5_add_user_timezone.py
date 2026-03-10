"""add_user_timezone

Revision ID: b7e9f2a1c3d5
Revises: 31c7f45b636f

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7e9f2a1c3d5"
down_revision: Union[str, None] = "31c7f45b636f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("user", sa.Column("timezone", sa.String(100), nullable=True))


def downgrade() -> None:
    op.drop_column("user", "timezone")
