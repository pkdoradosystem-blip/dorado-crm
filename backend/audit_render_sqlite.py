import os
import sqlite3
from pathlib import Path

if os.getenv("DATABASE_URL"):
    raise SystemExit("STOP: DATABASE_URL must be absent")

db_path = Path(__file__).resolve().parent / "dorado_crm.db"

if not db_path.exists():
    raise SystemExit("STOP: SQLite database missing")

conn = sqlite3.connect(
    f"file:{db_path.as_posix()}?mode=ro",
    uri=True
)

required_tables = [
    "leads",
    "quotation_master",
    "quotation_lift_items",
    "quotation_word_templates",
    "quotation_word_template_types",
    "quotation_word_template_defaults",
    "quotation_generated_documents",
]

try:
    print("=== RENDER TEST SQLITE AUDIT ===", flush=True)

    for table in required_tables:
        exists = conn.execute(
            "SELECT 1 FROM sqlite_master "
            "WHERE type='table' AND name=?",
            (table,)
        ).fetchone()

        if not exists:
            print(f"{table}: MISSING", flush=True)
            continue

        count = conn.execute(
            f'SELECT COUNT(*) FROM "{table}"'
        ).fetchone()[0]

        print(f"{table}: {count} rows", flush=True)

finally:
    conn.close()

print("=== SQLITE AUDIT COMPLETE ===", flush=True)
