from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, date, timedelta

from app.database import get_db
from app.models.user import User
from app.models.gamification import UserAvatar, Achievement, UserAchievement, XPTransaction
from app.models.study import StudySession, Quiz, Flashcard
from app.models.health import SleepLog, MoodEntry, MedicationLog
from app.models.daily import HabitEntry, HabitCompletion
from app.utils.auth import get_current_user

router = APIRouter(prefix="/gamification", tags=["gamification"])

XP_PER_LEVEL = 500
COINS_PER_10_XP = 1


def _calculate_level(total_xp: int) -> int:
    return max(1, total_xp // XP_PER_LEVEL + 1)


# STATS

@router.get("/stats")
def get_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    level = _calculate_level(current_user.total_xp)
    xp_in_current_level = current_user.total_xp % XP_PER_LEVEL
    xp_for_next_level = XP_PER_LEVEL

    # Recent XP transactions (last 20)
    recent_xp = (
        db.query(XPTransaction)
        .filter(XPTransaction.user_id == current_user.id)
        .order_by(XPTransaction.created_at.desc())
        .limit(20)
        .all()
    )

    # Count unlocked achievements
    unlocked_count = (
        db.query(UserAchievement)
        .filter(
            UserAchievement.user_id == current_user.id,
            UserAchievement.is_unlocked == True,
        )
        .count()
    )
    total_achievements = db.query(Achievement).count()

    return {
        "total_xp": current_user.total_xp,
        "level": level,
        "coins": current_user.coins,
        "streak_days": current_user.streak_days,
        "xp_in_current_level": xp_in_current_level,
        "xp_for_next_level": xp_for_next_level,
        "level_progress_pct": round(xp_in_current_level / xp_for_next_level * 100, 1),
        "achievements_unlocked": unlocked_count,
        "achievements_total": total_achievements,
        "recent_xp": [
            {
                "id": str(tx.id),
                "amount": tx.amount,
                "source": tx.source,
                "description": tx.description,
                "created_at": tx.created_at.isoformat() if tx.created_at else None,
            }
            for tx in recent_xp
        ],
    }


# ACHIEVEMENTS

@router.get("/achievements")
def get_achievements(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    all_achievements = db.query(Achievement).order_by(Achievement.category, Achievement.name).all()

    # Get user's progress on each
    user_achievements = {
        str(ua.achievement_id): ua
        for ua in db.query(UserAchievement)
        .filter(UserAchievement.user_id == current_user.id)
        .all()
    }

    result = []
    for ach in all_achievements:
        ua = user_achievements.get(str(ach.id))
        progress = _compute_achievement_progress(current_user, ach, db)
        result.append({
            "id": str(ach.id),
            "name": ach.name,
            "description": ach.description,
            "category": ach.category,
            "icon": ach.icon,
            "rarity": ach.rarity,
            "xp_reward": ach.xp_reward,
            "coin_reward": ach.coin_reward,
            "condition_type": ach.condition_type,
            "condition_value": ach.condition_value,
            "progress": progress,
            "progress_pct": min(100, round(progress / max(1, ach.condition_value) * 100)),
            "is_unlocked": ua.is_unlocked if ua else False,
            "unlocked_at": ua.unlocked_at.isoformat() if ua and ua.is_unlocked else None,
        })

    return result


@router.post("/achievements/check")
def check_achievements(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    all_achievements = db.query(Achievement).all()
    newly_unlocked = []

    for ach in all_achievements:
        # Check if already unlocked
        ua = (
            db.query(UserAchievement)
            .filter(
                UserAchievement.user_id == current_user.id,
                UserAchievement.achievement_id == ach.id,
            )
            .first()
        )

        if ua and ua.is_unlocked:
            continue  # Already unlocked

        progress = _compute_achievement_progress(current_user, ach, db)

        if progress >= ach.condition_value:
            # Unlock!
            if not ua:
                ua = UserAchievement(
                    user_id=current_user.id,
                    achievement_id=ach.id,
                )
                db.add(ua)

            ua.is_unlocked = True
            ua.progress = progress
            ua.unlocked_at = datetime.utcnow()

            # Award XP and coins
            current_user.total_xp += ach.xp_reward
            current_user.coins += ach.coin_reward
            current_user.level = _calculate_level(current_user.total_xp)

            # Log XP transaction
            db.add(XPTransaction(
                user_id=current_user.id,
                amount=ach.xp_reward,
                source="achievement",
                description=f"Unlocked: {ach.name}",
                reference_id=ach.id,
            ))

            newly_unlocked.append({
                "name": ach.name,
                "description": ach.description,
                "rarity": ach.rarity,
                "xp_reward": ach.xp_reward,
                "coin_reward": ach.coin_reward,
                "icon": ach.icon,
            })
        else:
            # Update progress
            if not ua:
                ua = UserAchievement(
                    user_id=current_user.id,
                    achievement_id=ach.id,
                    progress=progress,
                )
                db.add(ua)
            else:
                ua.progress = progress

    db.commit()

    return {
        "checked": len(all_achievements),
        "newly_unlocked": newly_unlocked,
        "total_unlocked": len([a for a in all_achievements
                               if any(u["name"] == a.name for u in newly_unlocked)]
                              ) + db.query(UserAchievement).filter(
            UserAchievement.user_id == current_user.id,
            UserAchievement.is_unlocked == True,
        ).count(),
    }


def _compute_achievement_progress(user: User, achievement: Achievement, db: Session) -> int:
    field = achievement.condition_field or ""
    ctype = achievement.condition_type

    try:
        if "study_sessions.count" in field:
            return db.query(StudySession).filter(StudySession.user_id == user.id).count()

        elif "study_sessions.duration" in field:
            # Max single session duration in minutes
            result = db.query(func.max(StudySession.duration_minutes)).filter(
                StudySession.user_id == user.id
            ).scalar()
            return result or 0

        elif "quizzes.percentage" in field:
            # Best quiz percentage
            from app.models.quiz_engine import GeneratedQuiz
            result = db.query(func.max(GeneratedQuiz.score_achieved)).filter(
                GeneratedQuiz.user_id == user.id,
                GeneratedQuiz.status == "completed",
            ).scalar()
            return int(result) if result else 0

        elif "flashcards.reviews" in field:
            return db.query(Flashcard).filter(
                Flashcard.user_id == user.id,
                Flashcard.total_reviews > 0,
            ).count()

        elif "sleep_logs.streak" in field:
            return _count_consecutive_sleep_days(user.id, db, min_hours=7)

        elif "mood_entries.streak" in field:
            return _count_consecutive_mood_days(user.id, db)

        elif "medications.adherence" in field:
            return _count_consecutive_med_days(user.id, db)

        elif "habits.streak" in field:
            # Best habit streak
            result = db.query(func.max(HabitEntry.streak_days)).filter(
                HabitEntry.user_id == user.id
            ).scalar()
            return result or 0

        elif "user.login_streak" in field:
            return user.streak_days

        else:
            return 0
    except Exception:
        return 0


def _count_consecutive_sleep_days(user_id, db, min_hours=7) -> int:
    logs = (
        db.query(SleepLog)
        .filter(SleepLog.user_id == user_id, SleepLog.total_hours >= min_hours)
        .order_by(SleepLog.date.desc())
        .limit(60)
        .all()
    )
    if not logs:
        return 0

    streak = 0
    expected = date.today()
    for log in logs:
        log_date = log.date if isinstance(log.date, date) else log.date.date()
        if log_date == expected:
            streak += 1
            expected -= timedelta(days=1)
        elif log_date < expected:
            break
    return streak


def _count_consecutive_mood_days(user_id, db) -> int:
    entries = (
        db.query(func.date(MoodEntry.created_at))
        .filter(MoodEntry.user_id == user_id)
        .group_by(func.date(MoodEntry.created_at))
        .order_by(func.date(MoodEntry.created_at).desc())
        .limit(60)
        .all()
    )
    if not entries:
        return 0

    streak = 0
    expected = date.today()
    for (entry_date,) in entries:
        if isinstance(entry_date, datetime):
            entry_date = entry_date.date()
        if entry_date == expected:
            streak += 1
            expected -= timedelta(days=1)
        else:
            break
    return streak


def _count_consecutive_med_days(user_id, db) -> int:
    logs = (
        db.query(func.date(MedicationLog.taken_at))
        .filter(MedicationLog.user_id == user_id, MedicationLog.status == "taken")
        .group_by(func.date(MedicationLog.taken_at))
        .order_by(func.date(MedicationLog.taken_at).desc())
        .limit(60)
        .all()
    )
    if not logs:
        return 0

    streak = 0
    expected = date.today()
    for (log_date,) in logs:
        if isinstance(log_date, datetime):
            log_date = log_date.date()
        if log_date == expected:
            streak += 1
            expected -= timedelta(days=1)
        else:
            break
    return streak


# XP ↔ COIN EXCHANGE

# Exchange rate — 20 XP = 1 coin. Mirrors the frontend `xpPerCash` constant
# in providers/dashboard_provider.dart so both sides agree on the price.
XP_PER_COIN = 20


@router.post("/exchange")
def exchange_xp_for_coins(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        coins_requested = int(payload.get("coins", 0))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Invalid coin amount")

    if coins_requested <= 0:
        raise HTTPException(status_code=400, detail="Coin amount must be > 0")

    xp_cost = coins_requested * XP_PER_COIN
    if (current_user.total_xp or 0) < xp_cost:
        raise HTTPException(status_code=400, detail="Not enough XP")

    current_user.total_xp = (current_user.total_xp or 0) - xp_cost
    current_user.coins = (current_user.coins or 0) + coins_requested
    current_user.level = _calculate_level(current_user.total_xp)

    # Ledger entry so the user's XP History screen shows the debit.
    db.add(XPTransaction(
        user_id=current_user.id,
        amount=-xp_cost,
        source="exchange",
        description=f"Exchanged {xp_cost} XP for {coins_requested} coins",
    ))

    db.commit()

    return {
        "total_xp": current_user.total_xp,
        "level": current_user.level,
        "coins": current_user.coins,
        "xp_spent": xp_cost,
        "coins_gained": coins_requested,
    }


# XP HISTORY

@router.get("/xp-history")
def get_xp_history(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    transactions = (
        db.query(XPTransaction)
        .filter(XPTransaction.user_id == current_user.id)
        .order_by(XPTransaction.created_at.desc())
        .limit(min(limit, 200))
        .all()
    )

    return [
        {
            "id": str(tx.id),
            "amount": tx.amount,
            "source": tx.source,
            "description": tx.description,
            "created_at": tx.created_at.isoformat() if tx.created_at else None,
        }
        for tx in transactions
    ]


# AVATAR

@router.post("/avatar")
def create_or_update_avatar(
    avatar_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    avatar = db.query(UserAvatar).filter(UserAvatar.user_id == current_user.id).first()

    if not avatar:
        avatar = UserAvatar(user_id=current_user.id)
        db.add(avatar)

    # Update fields
    for field in [
        "gender", "skin_tone", "base_image",
        "hair_style", "hair_color", "facial_hair",
        "eyes_style", "nose_style", "mouth_style",
        "clothes_style", "accessory_1", "accessory_2",
    ]:
        if field in avatar_data:
            setattr(avatar, field, avatar_data[field])

    db.commit()
    db.refresh(avatar)

    return _avatar_response(avatar)


@router.get("/avatar/me")
def get_my_avatar(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    avatar = db.query(UserAvatar).filter(UserAvatar.user_id == current_user.id).first()
    if not avatar:
        return None

    return _avatar_response(avatar)


@router.get("/avatar/expression")
def get_avatar_expression(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Check latest mood entry (today)
    latest_mood = (
        db.query(MoodEntry)
        .filter(
            MoodEntry.user_id == current_user.id,
            func.date(MoodEntry.created_at) == date.today(),
        )
        .order_by(MoodEntry.created_at.desc())
        .first()
    )

    if latest_mood and latest_mood.mood:
        mood_name = latest_mood.mood.name.lower() if hasattr(latest_mood.mood, 'name') else "neutral"
        mood_to_expression = {
            "happy": "happy", "sad": "sad", "anxious": "anxious",
            "calm": "calm", "excited": "excited", "tired": "tired",
            "angry": "angry", "focused": "focused",
        }
        expression = mood_to_expression.get(mood_name, "neutral")
    else:
        # Infer from data
        latest_sleep = (
            db.query(SleepLog)
            .filter(SleepLog.user_id == current_user.id)
            .order_by(SleepLog.date.desc())
            .first()
        )
        if latest_sleep and latest_sleep.total_hours and latest_sleep.total_hours < 5:
            expression = "tired"
        elif latest_sleep and latest_sleep.total_hours and latest_sleep.total_hours >= 8:
            expression = "happy"
        else:
            # Time-based default
            hour = datetime.now().hour
            if 5 <= hour < 12:
                expression = "happy"
            elif 12 <= hour < 17:
                expression = "focused"
            elif 17 <= hour < 21:
                expression = "calm"
            else:
                expression = "sleepy"

    # Update avatar's current expression
    avatar = db.query(UserAvatar).filter(UserAvatar.user_id == current_user.id).first()
    if avatar:
        avatar.current_expression = expression
        db.commit()

    return {
        "expression": expression,
        "source": "mood" if latest_mood else "inferred",
    }


def _avatar_response(avatar: UserAvatar) -> dict:
    return {
        "id": str(avatar.id),
        "gender": avatar.gender,
        "skin_tone": avatar.skin_tone,
        "base_image": avatar.base_image,
        "hair_style": avatar.hair_style,
        "hair_color": avatar.hair_color,
        "facial_hair": avatar.facial_hair,
        "eyes_style": avatar.eyes_style,
        "nose_style": avatar.nose_style,
        "mouth_style": avatar.mouth_style,
        "clothes_style": avatar.clothes_style,
        "accessory_1": avatar.accessory_1,
        "accessory_2": avatar.accessory_2,
        "unlocked_items": avatar.unlocked_items or [],
        "current_expression": avatar.current_expression,
    }


# STORE

# Store item catalog — exclusive items not in avatar customization
STORE_ITEMS = [
    {"id": "clothes_sweater_babypink", "name": "Pink Sweater", "category": "clothes", "price": 15, "rarity": "uncommon", "asset_key": "sweater-babypink"},
    {"id": "clothes_sweater_brown", "name": "Brown Sweater", "category": "clothes", "price": 12, "rarity": "common", "asset_key": "sweater-brown"},
    {"id": "clothes_cneck_brown", "name": "Brown C-Neck", "category": "clothes", "price": 10, "rarity": "common", "asset_key": "c-neck-brown"},
    {"id": "clothes_cneck_olive", "name": "Olive C-Neck", "category": "clothes", "price": 12, "rarity": "common", "asset_key": "c-neck-olive"},
    {"id": "clothes_nightdress_babypink", "name": "Pink Night Dress", "category": "clothes", "price": 18, "rarity": "uncommon", "asset_key": "night-dress-babypink"},
    {"id": "clothes_nightdress_brown", "name": "Brown Night Dress", "category": "clothes", "price": 15, "rarity": "common", "asset_key": "night-dress-brown"},
    {"id": "clothes_offshoulder_olive", "name": "Olive Off-Shoulder", "category": "clothes", "price": 18, "rarity": "uncommon", "asset_key": "offshoulder-olive"},
    {"id": "clothes_tanktop_babypink", "name": "Pink Tank Top", "category": "clothes", "price": 10, "rarity": "common", "asset_key": "tank-top-babypink"},
    {"id": "clothes_tanktop_brown", "name": "Brown Tank Top", "category": "clothes", "price": 8, "rarity": "common", "asset_key": "tank-top-brown"},
    {"id": "clothes_vneck_brown", "name": "Brown V-Neck", "category": "clothes", "price": 12, "rarity": "common", "asset_key": "v-neck-sweater-brown"},
    {"id": "clothes_vneck_olive", "name": "Olive V-Neck", "category": "clothes", "price": 15, "rarity": "uncommon", "asset_key": "v-neck-sweater-olive"},
    {"id": "hair_pink", "name": "Pink Hair Dye", "category": "hair", "price": 25, "rarity": "rare", "asset_key": "pink"},
    {"id": "hair_silver", "name": "Silver Hair Dye", "category": "hair", "price": 25, "rarity": "rare", "asset_key": "silver"},
    {"id": "hair_darkblue", "name": "Blue Hair Dye", "category": "hair", "price": 30, "rarity": "rare", "asset_key": "darkblue"},
    {"id": "glasses_star", "name": "Star Glasses", "category": "accessories", "price": 20, "rarity": "rare", "asset_key": "star-glasses"},
    {"id": "glasses_heart", "name": "Heart Glasses", "category": "accessories", "price": 20, "rarity": "rare", "asset_key": "heart-glasses"},
    {"id": "sunglasses", "name": "Cool Sunglasses", "category": "accessories", "price": 25, "rarity": "rare", "asset_key": "sunglasses"},
    {"id": "hat_magician", "name": "Magician Hat", "category": "accessories", "price": 40, "rarity": "epic", "asset_key": "magician-hat-blue"},
    {"id": "hat_french", "name": "French Beret", "category": "accessories", "price": 30, "rarity": "rare", "asset_key": "french-cap-blue"},
    {"id": "winter_cap", "name": "Winter Cap", "category": "accessories", "price": 15, "rarity": "uncommon", "asset_key": "winter-cap-red"},
    {"id": "tie_bowtie", "name": "Bow Tie", "category": "accessories", "price": 10, "rarity": "common", "asset_key": "boy-tie-green"},
    {"id": "flower_red", "name": "Red Flower", "category": "accessories", "price": 8, "rarity": "common", "asset_key": "flower-red"},
    {"id": "hairband_blue", "name": "Blue Hairband", "category": "accessories", "price": 12, "rarity": "common", "asset_key": "hairband1-blue"},
    {"id": "boost_2x_xp", "name": "2x XP", "category": "boosts", "price": 30, "rarity": "epic", "asset_key": ""},
    {"id": "boost_focus", "name": "Focus Boost", "category": "boosts", "price": 20, "rarity": "rare", "asset_key": ""},
    {"id": "boost_streak", "name": "Streak Shield", "category": "boosts", "price": 35, "rarity": "epic", "asset_key": ""},
]


@router.get("/store/catalog")
def get_store_catalog(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    avatar = db.query(UserAvatar).filter(UserAvatar.user_id == current_user.id).first()
    owned = avatar.unlocked_items if avatar and avatar.unlocked_items else []

    return {
        "coins": current_user.coins,
        "items": [
            {**item, "owned": item["id"] in owned}
            for item in STORE_ITEMS
        ],
    }


@router.post("/store/purchase")
def purchase_item(
    purchase: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item_id = purchase.get("item_id")
    item = next((i for i in STORE_ITEMS if i["id"] == item_id), None)

    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # Check if already owned
    avatar = db.query(UserAvatar).filter(UserAvatar.user_id == current_user.id).first()
    if not avatar:
        raise HTTPException(status_code=400, detail="Create an avatar first")

    owned = avatar.unlocked_items or []
    if item_id in owned:
        raise HTTPException(status_code=400, detail="Item already owned")

    # Check coins
    if current_user.coins < item["price"]:
        raise HTTPException(status_code=400, detail="Not enough coins")

    # Deduct coins and add item. We assign a brand-new list to
    # ``avatar.unlocked_items`` instead of mutating the existing list in
    # place. The column is wrapped with ``MutableList.as_mutable(JSONB)``
    # at the model layer, so in-place mutations ARE now tracked — but
    # brand-new list assignment is the most unambiguous signal and also
    # works against legacy sessions where the column happened to be
    # loaded before the MutableList wrapper was applied.
    current_user.coins -= item["price"]
    avatar.unlocked_items = [*owned, item_id]
    # Belt-and-suspenders: explicitly flag the JSONB column dirty so the
    # change flushes even if the list identity happens to match. This
    # was the root cause of the "items disappear after I log back in"
    # bug the user reported.
    from sqlalchemy.orm.attributes import flag_modified
    flag_modified(avatar, "unlocked_items")

    # Log transaction
    db.add(XPTransaction(
        user_id=current_user.id,
        amount=-item["price"],
        source="store",
        description=f"Purchased: {item['name']}",
    ))

    db.commit()
    db.refresh(avatar)

    return {
        "success": True,
        "item": item,
        "coins_remaining": current_user.coins,
        "unlocked_items": list(avatar.unlocked_items or []),
    }


@router.get("/store/inventory")
def get_inventory(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    avatar = db.query(UserAvatar).filter(UserAvatar.user_id == current_user.id).first()
    owned_ids = avatar.unlocked_items if avatar and avatar.unlocked_items else []

    return {
        "coins": current_user.coins,
        "items": [item for item in STORE_ITEMS if item["id"] in owned_ids],
    }
