"""
Login debug script — run this to diagnose auth issues.
Usage: python test_login_debug.py
"""

import bcrypt
import sys

sys.path.insert(0, ".")

from app.database import SessionLocal
from app.models.user import User


def test_bcrypt_roundtrip():
    password = "TestPass@123"
    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12))
    result = bcrypt.checkpw(password.encode("utf-8"), hashed)
    print(f"[TEST 1] bcrypt roundtrip: {'PASS' if result else 'FAIL'}")
    print(f"  Password: {password}")
    print(f"  Hash: {hashed.decode('utf-8')}")
    print(f"  Verify: {result}")
    return result


def test_database_user():
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print(f"\n[TEST 2] Users in database: {len(users)}")
        for u in users:
            print(f"  - Email: {u.email}")
            print(f"    Display Name: {u.display_name}")
            print(f"    Hash prefix: {u.hashed_password[:4] if u.hashed_password else 'NONE'}")
    finally:
        db.close()


def test_passlib_hash_compat():
    try:
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

        password = "TestPass@123"
        passlib_hash = pwd_context.hash(password)
        print(f"\n[TEST 3] passlib compatibility:")
        print(f"  passlib hash: {passlib_hash}")

        result = bcrypt.checkpw(
            password.encode("utf-8"),
            passlib_hash.encode("utf-8"),
        )
        print(f"  bcrypt.checkpw on passlib hash: {result}")

        passlib_result = pwd_context.verify(password, passlib_hash)
        print(f"  passlib.verify on passlib hash: {passlib_result}")

    except Exception as e:
        print(f"\n[TEST 3] passlib test error: {e}")


if __name__ == "__main__":
    print("=" * 50)
    print("Login Debug")
    print("=" * 50)

    test_bcrypt_roundtrip()
    test_database_user()
    test_passlib_hash_compat()

    print("\n" + "=" * 50)
    print("Done! Check results above.")
