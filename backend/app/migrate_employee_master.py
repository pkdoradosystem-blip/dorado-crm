from sqlalchemy import inspect, text

from .database import engine


# =========================================================
# EMPLOYEE MASTER SAFE MIGRATION
# Adds only missing columns.
# Existing employee records are NOT deleted or replaced.
# =========================================================

EMPLOYEE_COLUMNS = {
    "father_name": "VARCHAR(150)",
    "date_of_birth": "TIMESTAMP",
    "gender": "VARCHAR(30)",
    "alternate_mobile": "VARCHAR(30)",

    "present_address": "TEXT",
    "permanent_address": "TEXT",

    "aadhaar_number": "VARCHAR(20)",
    "pan_number": "VARCHAR(20)",

    "uan_number": "VARCHAR(30)",
    "pf_number": "VARCHAR(50)",
    "esic_number": "VARCHAR(50)",

    "bank_name": "VARCHAR(150)",
    "bank_account_holder_name": "VARCHAR(150)",
    "bank_account_number": "VARCHAR(50)",
    "bank_ifsc": "VARCHAR(20)",
    "bank_branch": "VARCHAR(150)",

    "security_pet_name_hash": "VARCHAR(255)",
}


def migrate_employee_master():
    inspector = inspect(engine)

    table_names = inspector.get_table_names()

    if "employee_master" not in table_names:
        print("employee_master table does not exist. Migration skipped.")
        return

    existing_columns = {
        column["name"]
        for column in inspector.get_columns("employee_master")
    }

    added_columns = []

    with engine.begin() as connection:
        for column_name, column_type in EMPLOYEE_COLUMNS.items():

            if column_name in existing_columns:
                print(f"EXISTS : {column_name}")
                continue

            connection.execute(
                text(
                    f'ALTER TABLE employee_master '
                    f'ADD COLUMN "{column_name}" {column_type}'
                )
            )

            added_columns.append(column_name)
            print(f"ADDED  : {column_name}")

    print("")
    print("=========================================")
    print("Employee Master migration completed.")
    print(f"Columns added: {len(added_columns)}")
    print("Existing employee records were preserved.")
    print("=========================================")


if __name__ == "__main__":
    migrate_employee_master()