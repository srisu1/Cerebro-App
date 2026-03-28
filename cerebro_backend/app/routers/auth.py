from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets

from app.database import get_db
from app.utils.email import send_reset_code_email
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse, UserUpdate, Token, GoogleAuthRequest
from app.utils.auth import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    verify_google_id_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _update_streak(user, now: datetime):
    # Increment login streak on consecutive calendar days, reset on gap
    today = now.date()
    if user.last_login is not None:
        last_date = user.last_login.date()
        if last_date == today:
            pass  # already counted today
        elif last_date == today - timedelta(days=1):
            user.streak_days = (user.streak_days or 0) + 1
        else:
            user.streak_days = 1  # gap → streak broken
    else:
        user.streak_days = 1  # very first login


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    # Check if email already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Create new user
    new_user = User(
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        display_name=user_data.display_name,
        university=user_data.university,
        course=user_data.course,
        year_of_study=user_data.year_of_study,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user


@router.post("/login", response_model=Token)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    # Find user
    user = db.query(User).filter(User.email == credentials.email).first()

    # Debug logging (remove in production)
    print(f"[LOGIN DEBUG] Email: {credentials.email}")
    print(f"[LOGIN DEBUG] User found: {user is not None}")
    if user:
        if user.hashed_password is None:
            print(f"[LOGIN DEBUG] User has no password (OAuth-only account)")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This account was created with Google. Please sign in with Google, or set a password first.",
            )
        else:
            print(f"[LOGIN DEBUG] Stored hash: {user.hashed_password[:20]}...")
            result = verify_password(credentials.password, user.hashed_password)
            print(f"[LOGIN DEBUG] Password verify result: {result}")
    else:
        result = False

    if not user or not result:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    # Update streak then last_login (order matters — streak reads last_login)
    now = datetime.utcnow()
    _update_streak(user, now)
    user.last_login = now
    db.commit()

    # Generate tokens
    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/google", response_model=Token)
def google_auth(request: GoogleAuthRequest, db: Session = Depends(get_db)):
    # Verify the Google ID token
    google_info = verify_google_id_token(request.id_token)

    google_id = google_info["sub"]
    email = google_info.get("email", "")
    name = google_info.get("name", "Cerebro User")
    picture = google_info.get("picture", "")
    email_verified = google_info.get("email_verified", False)

    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google account does not have an email address",
        )

    # 1. Check if user exists by google_id
    user = db.query(User).filter(User.google_id == google_id).first()

    if not user:
        # 2. Check if user exists by email (link Google to existing account)
        user = db.query(User).filter(User.email == email).first()
        if user:
            # Link Google ID to existing email-based account
            user.google_id = google_id
            user.auth_provider = "google" if not user.hashed_password else user.auth_provider
            if picture and not user.avatar_url:
                user.avatar_url = picture
        else:
            # 3. Create a new user (OAuth-only, no password)
            user = User(
                email=email,
                hashed_password=None,
                display_name=name,
                google_id=google_id,
                auth_provider="google",
                avatar_url=picture,
                is_verified=email_verified,
                is_active=True,
            )
            db.add(user)

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    # Update streak then last_login (order matters — streak reads last_login)
    now = datetime.utcnow()
    _update_streak(user, now)
    user.last_login = now
    db.commit()
    db.refresh(user)

    print(f"[GOOGLE AUTH] User: {user.email} (streak={user.streak_days})")

    # Generate JWT tokens
    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/refresh", response_model=Token)
def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = payload.get("sub")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/set-password")
def set_password(
    password_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    new_password = password_data.get("password")
    if not new_password or len(new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters",
        )

    # If user already has a password, require old_password
    if current_user.hashed_password is not None:
        old_password = password_data.get("old_password")
        if not old_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current password is required to change password",
            )
        if not verify_password(old_password, current_user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect",
            )

    current_user.hashed_password = hash_password(new_password)
    # If they were Google-only, mark as both providers
    if current_user.auth_provider == "google":
        current_user.auth_provider = "google+email"
    db.commit()

    return {"message": "Password set successfully"}


@router.post("/forgot-password")
def forgot_password(body: dict, db: Session = Depends(get_db)):
    email = body.get("email", "").strip().lower()
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is required",
        )

    user = db.query(User).filter(User.email == email).first()
    if not user:
        # Don't reveal whether the email exists (security best practice)
        return {"message": "If an account with that email exists, a reset code has been generated."}

    # Generate a 6-digit reset code
    reset_code = f"{secrets.randbelow(1000000):06d}"
    user.reset_token = reset_code
    user.reset_token_expires = datetime.utcnow() + timedelta(minutes=15)
    db.commit()

    # Send the reset code via email
    email_sent = send_reset_code_email(
        to_email=user.email,
        reset_code=reset_code,
        display_name=user.display_name or "there",
    )

    if not email_sent:
        print(f"[PASSWORD RESET] Email failed — code for {email}: {reset_code}")

    return {
        "message": "If an account with that email exists, a reset code has been sent to that email.",
    }


@router.post("/reset-password")
def reset_password(body: dict, db: Session = Depends(get_db)):
    email = body.get("email", "").strip().lower()
    reset_code = body.get("reset_code", "").strip()
    new_password = body.get("new_password", "")

    if not email or not reset_code or not new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email, reset code, and new password are required",
        )

    if len(new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters",
        )

    user = db.query(User).filter(User.email == email).first()
    if not user or user.reset_token != reset_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reset code",
        )

    if user.reset_token_expires and user.reset_token_expires.replace(tzinfo=None) < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reset code has expired. Please request a new one.",
        )

    # Set the new password
    user.hashed_password = hash_password(new_password)
    user.reset_token = None
    user.reset_token_expires = None
    if user.auth_provider == "google":
        user.auth_provider = "google+email"
    db.commit()

    return {"message": "Password reset successfully. You can now sign in."}


@router.get("/me", response_model=UserResponse)
def get_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
def update_profile(
    updates: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    update_data = updates.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)

    db.commit()
    db.refresh(current_user)
    return current_user
