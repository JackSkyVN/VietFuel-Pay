"""Alembic migration script template."""
# Revision identifiers, used by Alembic.
revision: str = "${up_revision}"
down_revision: str | None = ${down_revision | n, repr}
branch_labels: str | tuple[str, ...] | None = ${branch_labels | n, repr}
depends_on: str | tuple[str, ...] | None = ${depends_on | n, repr}

from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
