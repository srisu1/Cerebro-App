from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime

from app.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse, UserUpdate, Token, GoogleAuthRequest
from app.utils.auth import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    decode_token, get_current_user, verify_google_id_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

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
    user = db.query(User).filter(User.email == credentials.email).first()

    # debug logging — remove later
    print(f"[LOGIN DEBUG] Email: {credentials.email}")
    print(f"[LOGIN DEBUG] User found: {user is not None}")
    if user:
        print(f"[LOGIN DEBUG] Stored hash: {user.hashed_password[:20]}...")
        result = verify_password(credentials.password, user.hashed_password)
        print(f"[LOGIN DEBUG] Password verify result: {result}")
    else:
        result = False

    if not user or not result:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")

    user.last_login = datetime.utcnow()
    db.commit()

    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/google", response_model=Token)
def google_auth(request: GoogleAuthRequest, db: Session = Depends(get_db)):
    google_info = verify_google_id_token(request.id_token)

    google_id = google_info["sub"]
    email = google_info.get("email", "")
    name = google_info.get("name", "Cerebro User")
    picture = google_info.get("picture", "")
    email_verified = google_info.get("email_verified", False)

    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google account has no email")

    user = db.query(User).filter(User.google_id == google_id).first()

    if not user:
        # check if email already exists, link google to it
        user = db.query(User).filter(User.email == email).first()
        if user:
            user.google_id = google_id
            user.auth_provider = "google" if not user.hashed_password else user.auth_provider
            if picture and not user.avatar_url:
                user.avatar_url = picture
        else:
            # new oauth-only user
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
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")

    user.last_login = datetime.utcnow()
    db.commit()
    db.refresh(user)

    print(f"[GOOGLE AUTH] User: {user.email} (google_id={google_id})")

    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/refresh", response_model=Token)
def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user_id = payload.get("sub")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return Token(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


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
