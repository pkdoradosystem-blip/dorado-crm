from io import BytesIO
from datetime import date
from types import SimpleNamespace

from docx import Document
from app.quotation_word_service import build_word_quotation
from app.word_preview_converter import convert_docx_to_pdf_linux

print("=== DORADO ACTUAL QUOTATION TEST ===", flush=True)

quotation = SimpleNamespace(
    id=999999,
    quotation_no="TEST-TRACTION-001",
    quotation_date=date(2026, 11, 13),
    customer_name="DORADO TEST CUSTOMER",
    site_address="TEST SITE ONLY",
    office_address="TEST OFFICE ONLY",
    mobile="0000000000",
    location="TEST LOCATION",
    grand_total=500000,
    payment_terms="50 percent advance",
    delivery_period="4 weeks",
    warranty_terms="12 months",
    commercial_data={
        "price_including_gst": 500000,
        "auto_door_selected": True,
        "auto_door_addon": 25000,
        "ss_cabin_selected": False,
        "ss_cabin_addon": 10000,
        "ard_selected": True,
        "ard_addon": 15000,
    },
    technical_data={
        "person_capacity": "6",
        "lift_type": "Passenger Traction Lift",
        "number_of_floor": "G+3",
        "no_of_stops": "4",
        "no_of_opening": "4",
        "shaft_width": "1600",
        "shaft_depth": "1600",
        "door_operation": "Automatic",
    },
)

template = Document()
template.add_heading("DORADO QUOTATION TEST", 0)
template.add_paragraph("Quotation: {{ quotation_no }}")
template.add_paragraph("Customer: {{ customer_name }}")
template.add_paragraph("Capacity: {{ capacity }}")
template.add_paragraph("Floor: {{ floor_rise }}")
template.add_paragraph("Final Price: {{ final_price_including_gst }}")

buffer = BytesIO()
template.save(buffer)

docx_bytes = build_word_quotation(
    quotation,
    buffer.getvalue(),
    db=None,
)

filled = Document(BytesIO(docx_bytes))
text = "\n".join(p.text for p in filled.paragraphs)

assert "TEST-TRACTION-001" in text
assert "DORADO TEST CUSTOMER" in text
assert "6" in text
assert "540,000.00" in text
assert "{{" not in text

print("WORD TEMPLATE RENDERING: SUCCESS", flush=True)

pdf_bytes = convert_docx_to_pdf_linux(docx_bytes)

assert pdf_bytes.startswith(b"%PDF-")
assert len(pdf_bytes) > 1000

print("PDF CONVERSION: SUCCESS", flush=True)
print("DOCX SIZE:", len(docx_bytes), flush=True)
print("PDF SIZE:", len(pdf_bytes), flush=True)
print("=== END-TO-END TEST PASSED ===", flush=True)
