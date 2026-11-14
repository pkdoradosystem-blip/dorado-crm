from pathlib import Path
from app.word_preview_converter import convert_docx_to_pdf_linux
import subprocess

source = Path(__file__).resolve().parent / "DORADO_LAYOUT_EXPERIMENT.docx"

if not source.exists():
    raise RuntimeError("Experiment Word missing")

print("=== DORADO LAYOUT EXPERIMENT START ===", flush=True)

pdf = convert_docx_to_pdf_linux(source.read_bytes())

if not pdf.startswith(b"%PDF-"):
    raise RuntimeError("Invalid experiment PDF")

output = source.with_suffix(".pdf")
output.write_bytes(pdf)

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

print("EXPERIMENT PDF PAGE COUNT:", pages, flush=True)
print("EXPERIMENT PDF SIZE:", len(pdf), flush=True)
print("=== DORADO LAYOUT EXPERIMENT COMPLETE ===", flush=True)
