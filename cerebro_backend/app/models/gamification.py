import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text,
    ForeignKey, DECIMAL, ARRAY
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.database import Base


class UserAvatar(Base):
    __tablename__ = "user_avatars"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)

    # avatar identity
    gender = Column(String(20), nullable=False)  # male, female
    skin_tone = Column(String(20), nullable=False)  # light, medium, dark
    base_image = Column(String(200), nullable=False)

    # customization layers
    hair_style = Column(String(100))
    hair_color = Column(String(7))
    facial_hair = Column(String(100))  # male only
    eyes_style = Column(String(100), default="neutral")
    nose_style = Column(String(100), default="neutral")
    mouth_style = Column(String(100), default="neutral")
    clothes_style = Column(String(100))
    accessory_1 = Column(String(100))  # glasses, hat, etc.
    accessory_2 = Column(String(100))

    # unlocked items from xp store
    unlocked_items = Column(JSONB, default=[])

    current_expression = Column(String(50), default="neutral")

    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="avatar")

    def __repr__(self):
        return f"<UserAvatar {self.gender} {self.skin_tone}>"


class Achievement(Base):
    __tablename__ = "achievements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(Text, nullable=False)
    category = Column(String(50), nullable=False)  # study, health, daily, social
    icon = Column(String(100))
    xp_reward = Column(Integer, default=50)
    coin_reward = Column(Integer, default=10)

    # unlock condition
    condition_type = Column(String(50), nullable=False)  # streak, count, score, milestone
    condition_value = Column(Integer, nullable=False)  # e.g., 7 for "7-day streak"
    condition_field = Column(String(100))  # e.g., "study_sessions.count"

    rarity = Column(String(20), default="common")  # common, rare, epic, legendary
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    user_achievements = relationship("UserAchievement", back_populates="achievement")

    def __repr__(self):
        return f"<Achievement {self.name} ({self.rarity})>"


class UserAchievement(Base):
    __tablename__ = "user_achievements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    achievement_id = Column(UUID(as_uuid=True), ForeignKey("achievements.id"), nullable=False)
    unlocked_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    progress = Column(Integer, default=0)
    is_unlocked = Column(Boolean, default=False)

    user = relationship("User", back_populates="achievements")
    achievement = relationship("Achievement", back_populates="user_achievements")

    def __repr__(self):
        return f"<UserAchievement {self.achievement_id} unlocked={self.is_unlocked}>"


class XPTransaction(Base):
    __tablename__ = "xp_transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    amount = Column(Integer, nullable=False)  # positive = gain, negative = spend
    source = Column(String(100), nullable=False)  # study_session, quiz, habit, achievement, store
    description = Column(Text)
    reference_id = Column(UUID(as_uuid=True))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User", back_populates="xp_transactions")

    def __repr__(self):
        return f"<XPTransaction {self.amount} XP from {self.source}>"
