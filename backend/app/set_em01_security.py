from getpass import getpass

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import EmployeeMaster


password_hash = PasswordHash.recommended()


def main():
    db: Session = SessionLocal()

    try:
        employee = (
            db.query(EmployeeMaster)
            .filter(EmployeeMaster.id == "EM01")
            .first()
        )

        if employee is None:
            print("ERROR: EM01 not found.")
            return

        print(f"Employee found: {employee.id} - {employee.employee_name}")

        dob = input("Enter Date of Birth (YYYY-MM-DD): ").strip()
        pet_name = getpass("Enter Pet Name: ").strip()

        if not dob:
            print("ERROR: Date of Birth is required.")
            return

        if not pet_name:
            print("ERROR: Pet Name is required.")
            return

        employee.date_of_birth = dob
        employee.security_pet_name_hash = password_hash.hash(
            pet_name.lower()
        )

        db.commit()

        print("")
        print("SUCCESS: EM01 security details updated.")
        print(f"Date of Birth: {dob}")
        print("Pet Name: stored securely as hash.")

    except Exception as exc:
        db.rollback()
        print(f"ERROR: {exc}")
        raise

    finally:
        db.close()


if __name__ == "__main__":
    main()