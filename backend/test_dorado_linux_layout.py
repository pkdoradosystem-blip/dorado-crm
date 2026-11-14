from pathlib import Path
from io import BytesIO
from zipfile import ZipFile
from lxml import etree

from app.word_preview_converter import convert_docx_to_pdf_linux

source = Path(__file__).resolve().parent / "DORADO_LINUX_LAYOUT_TEST.docx"

if not source.exists():
    raise RuntimeError("Test DOCX missing")

docx_bytes = source.read_bytes()

with ZipFile(BytesIO(docx_bytes)) as z:
    root = etree.fromstring(z.read("word/document.xml"))

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

text = " ".join(
    t.text or "" for t in root.iter(W + "t")
)

for value in ("TEST CUSTOMER", "TEST-MODEL", "TEST LOCATION", "500,000.00"):
    if value not in text:
        raise RuntimeError("Missing dummy value: " + value)

print("ORIGINAL DORADO LAYOUT TEST: START", flush=True)

pdf_bytes = convert_docx_to_pdf_linux(docx_bytes)

if not pdf_bytes.startswith(b"%PDF-"):
    raise RuntimeError("Invalid PDF")

output = source.with_suffix(".pdf")
output.write_bytes(pdf_bytes)

print("LINUX PDF CREATED:", output, flush=True)
print("PDF SIZE:", len(pdf_bytes), flush=True)

import subprocess

result = subprocess.run(
    ["pdfinfo", str(output)],
    capture_output=True,
    text=True,
    check=True,
)

pages = None

for line in result.stdout.splitlines():
    if line.startswith("Pages:"):
        pages = int(line.split(":", 1)[1].strip())
        break

print("PDF PAGE COUNT:", pages, flush=True)

if pages != 3:
    raise RuntimeError(
        f"Expected 3 pages, got {pages}"
    )

print("ORIGINAL 3 PAGE COUNT: VERIFIED", flush=True)

print("=== STEP 345 LINUX CONVERSION PASSED ===", flush=True)
