from sqlalchemy import inspect, text
from app.database import engine, Base
from app import models

# Create quotation tables if they do not exist.
Base.metadata.create_all(bind=engine)

inspector = inspect(engine)

required_master = {
    "quotation_type": "VARCHAR(50)",
    "power_type": "VARCHAR(30)",
    "template_code": "VARCHAR(100)",
    "technical_data": "TEXT",
    "commercial_data": "TEXT",
}

required_items = {
    "technical_data": "TEXT",
    "structure_data": "TEXT",
    "civil_data": "TEXT",
    "covering_data": "TEXT",
}


def add_missing_columns(table_name, required):
    inspector = inspect(engine)

    existing = {
        col["name"]
        for col in inspector.get_columns(table_name)
    }

    with engine.begin() as conn:
        for name, sql_type in required.items():
            if name in existing:
                print(f"{table_name}.{name}: EXISTS")
                continue

            conn.execute(
                text(
                    f'ALTER TABLE {table_name} '
                    f'ADD COLUMN {name} {sql_type}'
                )
            )

            print(f"{table_name}.{name}: ADDED")


add_missing_columns(
    "quotation_master",
    required_master,
)

add_missing_columns(
    "quotation_lift_items",
    required_items,
)

# Final verification
inspector = inspect(engine)

master_columns = {
    c["name"]
    for c in inspector.get_columns(
        "quotation_master"
    )
}

item_columns = {
    c["name"]
    for c in inspector.get_columns(
        "quotation_lift_items"
    )
}

assert set(required_master).issubset(
    master_columns
)

assert set(required_items).issubset(
    item_columns
)

print("")
print("QUOTATION DATABASE MIGRATION PASSED")
print("quotation_master: OK")
print("quotation_lift_items: OK")
