"""Add Google OAuth fields to users table

Revision ID: 001_google_oauth
Revises: None
Create Date: 2026-02-23

Adds google_id, auth_provider, and avatar_url columns.
Makes hashed_password nullable for OAuth-only users.
"""

from alembic import op
import sqlalchemy as sa

revision = "001_google_oauth"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("google_id", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("auth_provider", sa.String(50), server_default="email", nullable=True))
    op.add_column("users", sa.Column("avatar_url", sa.String(500), nullable=True))

    op.create_index("ix_users_google_id", "users", ["google_id"], unique=True)

    # make hashed_password nullable for OAuth-only users
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=True)


def downgrade() -> None:
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=False)
    op.drop_index("ix_users_google_id", table_name="users")
    op.drop_column("users", "avatar_url")
    op.drop_column("users", "auth_provider")
    op.drop_column("users", "google_id")
