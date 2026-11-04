from io import BytesIO
from pathlib import Path
from docx import Document
from app.word_preview_converter import convert_docx_to_pdf_linux

doc = Document()
doc.add_heading("DORADO SYSTEM", 0)
doc.add_heading("Elevator Quotation - PDF Test", 1)

doc.add_paragraph("Customer: Test Customer")
doc.add_paragraph("Lift Type: Passenger Elevator")
doc.add_paragraph("Capacity: 6 Passenger")
doc.add_paragraph("Travel: G+3")

table = doc.add_table(rows=2, cols=2)
table.style = "Table Grid"
table.cell(0, 0).text = "Description"
table.cell(0, 1).text = "Value"
table.cell(1, 0).text = "Quotation Amount"
table.cell(1, 1).text = "INR 500000"

buffer = BytesIO()
doc.save(buffer)

pdf = convert_docx_to_pdf_linux(buffer.getvalue())

assert pdf.startswith(b"%PDF-"), "Invalid PDF"
assert len(pdf) > 1000, "PDF too small"

output = Path("/tmp/dorado_test.pdf")
output.write_bytes(pdf)

print("WORD TO PDF CONVERSION SUCCESS")
print("PDF SIZE:", len(pdf), "bytes")
