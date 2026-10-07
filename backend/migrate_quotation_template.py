from sqlalchemy import inspect

from app.database import Base, engine
from app import models  # noqa: F401


def migrate():
    Base.metadata.create_all(bind=engine)

    inspector = inspect(engine)
    tables = set(inspector.get_table_names())

    if "quotation_templates" not in tables:
        raise RuntimeError(
            "quotation_templates table was not created"
        )

    columns = {
        column["name"]
        for column in inspector.get_columns(
            "quotation_templates"
        )
    }

    required = {
        "id",
        "template_code",
        "template_name",
        "quotation_type",
        "version_no",
        "template_content",
        "layout_config",
        "is_default",
        "active",
        "created_by",
        "created_at",
        "updated_by",
        "updated_at",
    }

    missing = required - columns

    if missing:
        raise RuntimeError(
            f"quotation_templates missing columns: {sorted(missing)}"
        )

    print("QUOTATION TEMPLATE MIGRATION PASSED")
    print("quotation_templates: OK")


if __name__ == "__main__":
    migrate()
