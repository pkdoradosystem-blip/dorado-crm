from sqlalchemy import (
    Column, Integer, BigInteger, String,
    LargeBinary, DateTime, MetaData, Table,
    create_engine, inspect, text
)
from sqlalchemy.sql import func
from app.database import DATABASE_URL

if not DATABASE_URL.startswith("sqlite"):
    raise SystemExit(
        "STOP: This migration is only for SQLite test database."
    )

engine = create_engine(DATABASE_URL)
metadata = MetaData()

generated_documents = Table(
    "quotation_generated_documents",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("quotation_id", Integer, nullable=False),
    Column("template_id", Integer, nullable=False),
    Column("revision_no", Integer, nullable=False),
    Column("version_no", Integer, nullable=False),
    Column("file_type", String(10), nullable=False),
    Column("file_name", String(255), nullable=False),
    Column("file_data", LargeBinary, nullable=False),
    Column("generated_by", Integer, nullable=True),
    Column("generated_at", DateTime, server_default=func.current_timestamp()),
)

metadata.create_all(bind=engine, tables=[generated_documents])

if inspect(engine).has_table("quotation_generated_documents"):
    print("SUCCESS: Test generated documents table ready")
else:
    raise RuntimeError("Table creation failed")

engine.dispose()
