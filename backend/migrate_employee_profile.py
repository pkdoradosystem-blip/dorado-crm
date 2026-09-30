from sqlalchemy import inspect, text

from app.database import engine


# =========================================================
# EMPLOYEE MASTER SAFE MIGRATION
# Adds ONLY missing columns.
# Existing employee records are preserved.
# Safe to run more than once.
# =========================================================

EMPLOYEE_COLUMNS = {
    # Personal
    "father_name": "VARCHAR(150)",
    "date_of_birth": "TIMESTAMP",
    "gender": "VARCHAR(30)",
    "alternate_mobile": "VARCHAR(30)",
    "present_address": "TEXT",
    "permanent_address": "TEXT",

    # Employment
    "employee_type": "VARCHAR(50)",
    "work_location": "VARCHAR(150)",
    "date_of_exit": "TIMESTAMP",

    # PF / ESIC applicability
    "pf_applicable": "BOOLEAN DEFAULT FALSE NOT NULL",
    "esic_applicable": "BOOLEAN DEFAULT FALSE NOT NULL",

    # Salary
    "basic_salary": "DOUBLE PRECISION",
    "gross_salary": "DOUBLE PRECISION",
    "ctc": "DOUBLE PRECISION",
    "hra": "DOUBLE PRECISION",
    "conveyance_allowance": "DOUBLE PRECISION",
    "other_allowance": "DOUBLE PRECISION",
    "employee_pf_contribution": "DOUBLE PRECISION",
    "employer_pf_contribution": "DOUBLE PRECISION",
    "employee_esic_contribution": "DOUBLE PRECISION",
    "employer_esic_contribution": "DOUBLE PRECISION",

    # Emergency / Personal
    "blood_group": "VARCHAR(20)",
    "emergency_contact_name": "VARCHAR(150)",
    "emergency_contact_mobile": "VARCHAR(30)",
    "emergency_contact_relation": "VARCHAR(50)",

    # Government / Identity
    "aadhaar_number": "VARCHAR(20)",
    "pan_number": "VARCHAR(20)",

    # PF / ESIC numbers
    "uan_number": "VARCHAR(30)",
    "pf_number": "VARCHAR(50)",
    "esic_number": "VARCHAR(50)",

    # Bank
    "bank_name": "VARCHAR(150)",
    "bank_account_holder_name": "VARCHAR(150)",
    "bank_account_number": "VARCHAR(50)",
    "bank_ifsc": "VARCHAR(20)",
    "bank_branch": "VARCHAR(150)",

    # Security
    "security_pet_name_hash": "VARCHAR(255)",
}


def migrate_employee_master():
    inspector = inspect(engine)

    if "employee_master" not in inspector.get_table_names():
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

    # -----------------------------------------------------
    # EMPLOYEE DOCUMENT TABLE
    # -----------------------------------------------------

    connection_inspector = inspect(engine)

    if "employee_documents" not in connection_inspector.get_table_names():
        with engine.begin() as connection:
            connection.execute(
                text(
                    """
                    CREATE TABLE employee_documents (
                        id SERIAL PRIMARY KEY,
                        employee_id VARCHAR(30) NOT NULL,
                        document_type VARCHAR(100) NOT NULL,
                        document_name VARCHAR(200),
                        document_number VARCHAR(100),
                        file_url TEXT,
                        issue_date TIMESTAMP,
                        expiry_date TIMESTAMP,
                        remarks TEXT,
                        active BOOLEAN DEFAULT TRUE NOT NULL,
                        uploaded_by VARCHAR(30),
                        uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT fk_employee_documents_employee
                            FOREIGN KEY (employee_id)
                            REFERENCES employee_master(id)
                    )
                    """
                )
            )

            connection.execute(
                text(
                    """
                    CREATE INDEX IF NOT EXISTS
                    ix_employee_documents_employee_id
                    ON employee_documents(employee_id)
                    """
                )
            )

        print("CREATED: employee_documents")
    else:
        print("EXISTS : employee_documents")

    print("")
    print("=========================================")
    print("Employee profile migration completed.")
    print(f"Columns added: {len(added_columns)}")

    if added_columns:
        print("Added columns:")
        for column_name in added_columns:
            print(f" - {column_name}")
    else:
        print("No new EmployeeMaster columns were required.")

    print("Existing employee records were preserved.")
    print("=========================================")


if __name__ == "__main__":
    migrate_employee_master()
