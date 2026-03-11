"""Add flashcard_decks table and deck_id to flashcards

Revision ID: 002_flashcard_decks
Revises: 001_google_oauth
Create Date: 2026-02-26

Creates the flashcard_decks table for organizing flashcards into sets.
Adds deck_id foreign key to the existing flashcards table.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "002_flashcard_decks"
down_revision = "001_google_oauth"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "flashcard_decks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("subject_id", UUID(as_uuid=True), sa.ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), server_default=""),
        sa.Column("color", sa.String(7), server_default="#A8D5A3"),
        sa.Column("icon", sa.String(50), server_default="layers"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.add_column(
        "flashcards",
        sa.Column("deck_id", UUID(as_uuid=True), sa.ForeignKey("flashcard_decks.id", ondelete="CASCADE"), nullable=True),
    )

    op.create_index("ix_flashcards_deck_id", "flashcards", ["deck_id"])


def downgrade() -> None:
    op.drop_index("ix_flashcards_deck_id", table_name="flashcards")
    op.drop_column("flashcards", "deck_id")
    op.drop_table("flashcard_decks")
