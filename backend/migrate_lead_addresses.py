from sqlalchemy import inspect, text

from app.database import engine


NEW_COLUMNS = {
    "construction_building_name": "VARCHAR(255)",
    "office_address": "TEXT",
    "site_address": "TEXT",
}


def main():
    inspector = inspect(engine)

    tables = inspector.get_table_names()

    if "leads" not in tables:
        raise RuntimeError("leads table not found")

    existing = {
        column["name"]
        for column in inspector.get_columns("leads")
    }

    with engine.begin() as connection:
        for name, sql_type in NEW_COLUMNS.items():

            if name in existing:
                print(f"{name}: already exists")
                continue

            connection.execute(
                text(
                    f'ALTER TABLE leads '
                    f'ADD COLUMN "{name}" {sql_type}'
                )
            )

            print(f"{name}: added")

    print("LEAD ADDRESS MIGRATION COMPLETE")


if __name__ == "__main__":
    main()
