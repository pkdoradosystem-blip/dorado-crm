from io import BytesIO
from pathlib import Path

from docx import Document
from app.word_preview_converter import convert_docx_to_pdf_linux

print("=== DORADO RENDER PDF SELF TEST ===", flush=True)

doc = Document()
doc.add_heading("DORADO SYSTEM", 0)
doc.add_heading("Sample Elevator Quotation", 1)

doc.add_paragraph("Customer: TEST CUSTOMER")
doc.add_paragraph("Capacity: 6 Passenger")
doc.add_paragraph("Stops: G+3")
doc.add_paragraph("Door: Automatic")

buffer = BytesIO()
doc.save(buffer)

docx_bytes = buffer.getvalue()

print("DOCX SIZE:", len(docx_bytes), flush=True)

pdf_bytes = convert_docx_to_pdf_linux(docx_bytes)

if not pdf_bytes.startswith(b"%PDF-"):
    raise RuntimeError("Invalid PDF header")

if len(pdf_bytes) < 1000:
    raise RuntimeError("PDF file too small")

print("PDF SIZE:", len(pdf_bytes), flush=True)
print("PDF HEADER: VALID", flush=True)
print("PDF CONVERSION: VERIFIED SUCCESS", flush=True)
