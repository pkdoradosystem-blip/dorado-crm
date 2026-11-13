#!/bin/sh
set -eu

echo "=== DORADO DOCKER TEST STARTUP ==="

if [ -n "${DATABASE_URL:-}" ]; then
    echo "STOP: DATABASE_URL must not be configured for this test"
    exit 1
fi

echo "=== SQLITE TEST MIGRATION ==="
python migrate_test_generated_documents.py

echo "=== RENDER SQLITE AUDIT ==="
python audit_render_sqlite.py

echo "=== LIBREOFFICE VERSION ==="
libreoffice --version

echo "=== WORD TO PDF SELF TEST ==="
python render_pdf_self_test.py

echo "=== STARTING FASTAPI ==="
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-10000}"
