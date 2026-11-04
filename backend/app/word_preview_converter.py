import os
import subprocess
import tempfile
from pathlib import Path


def convert_docx_to_pdf(docx_bytes: bytes) -> bytes:
    if os.name != "nt":
        raise RuntimeError("Windows Microsoft Word is required")

    with tempfile.TemporaryDirectory() as folder:
        folder = Path(folder)
        docx = folder / "quotation.docx"
        pdf = folder / "quotation.pdf"
        ps1 = folder / "convert.ps1"

        docx.write_bytes(docx_bytes)

        ps1.write_text(
            """
param(
    [string]$InputDocx,
    [string]$OutputPdf
)

$ErrorActionPreference = 'Stop'
$word = $null
$doc = $null

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $doc = $word.Documents.Open($InputDocx)

    if ($null -eq $doc) {
        throw "Word document could not be opened"
    }

    $doc.ExportAsFixedFormat($OutputPdf, 17)
}
finally {
    if ($null -ne $doc) {
        $doc.Close($false)
    }
    if ($null -ne $word) {
        $word.Quit()
    }
}
""",
            encoding="utf-8",
        )

        result = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ps1),
                str(docx),
                str(pdf),
            ],
            capture_output=True,
            text=True,
            timeout=90,
        )

        if result.returncode != 0 or not pdf.exists():
            raise RuntimeError(
                "Word PDF conversion failed: "
                + result.stderr[-1500:]
            )

        return pdf.read_bytes()

# Linux conversion for Render
def convert_docx_to_pdf_linux(docx_bytes: bytes) -> bytes:
    import shutil

    soffice = shutil.which("libreoffice") or shutil.which("soffice")
    if not soffice:
        raise RuntimeError("LibreOffice is not installed")

    with tempfile.TemporaryDirectory() as folder:
        folder = Path(folder)
        docx = folder / "quotation.docx"
        docx.write_bytes(docx_bytes)

        profile = folder / "lo_profile"

        result = subprocess.run(
            [
                soffice,
                "-env:UserInstallation=" + profile.as_uri(),
                "--headless",
                "--convert-to", "pdf",
                "--outdir", str(folder),
                str(docx),
            ],
            capture_output=True,
            text=True,
            timeout=90,
        )

        pdf = folder / "quotation.pdf"

        if result.returncode != 0 or not pdf.exists():
            raise RuntimeError(
                "LibreOffice conversion failed: "
                + result.stderr[-1000:]
            )

        return pdf.read_bytes()
