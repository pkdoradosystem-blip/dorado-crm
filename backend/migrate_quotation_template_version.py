from sqlalchemy import inspect, text

from app.database import engine


def migrate():
    inspector = inspect(engine)

    columns = {
        column["name"]
        for column in inspector.get_columns("quotation_master")
    }

    if "template_version" not in columns:
        with engine.begin() as connection:
            connection.execute(
                text(
                    "ALTER TABLE quotation_master "
                    "ADD COLUMN template_version INTEGER"
                )
            )

        print("template_version column added")
    else:
        print("template_version column already exists")

    inspector = inspect(engine)

    columns = {
        column["name"]
        for column in inspector.get_columns("quotation_master")
    }

    if "template_version" not in columns:
        raise RuntimeError(
            "quotation_master.template_version migration failed"
        )

    print("QUOTATION TEMPLATE VERSION MIGRATION PASSED")
    print("quotation_master.template_version: OK")


if __name__ == "__main__":
    migrate()
