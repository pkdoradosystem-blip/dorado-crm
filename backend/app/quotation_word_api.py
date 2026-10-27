
import io
import re
import zipfile
from datetime import datetime

from fastapi import (
    APIRouter, Depends, File, Form,
    HTTPException, UploadFile
)
from fastapi.responses import StreamingResponse
from sqlalchemy import (
    Table, Column, Integer, String,
    LargeBinary, DateTime, MetaData, select
)
from sqlalchemy.orm import Session

from app.database import engine, get_db
from app.models import EmployeeMaster, QuotationMaster
from app.admin_api import get_current_user, require_permission
from app.quotation_word_service import build_word_quotation


router = APIRouter(
    prefix="/api/v1/quotation-word",
    tags=["Quotation Word Templates"],
)

metadata = MetaData()

word_templates = Table(
    "quotation_word_templates",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("template_name", String(200), nullable=False),
    Column("version_no", Integer, nullable=False),
    Column("file_name", String(255), nullable=False),
    Column("file_data", LargeBinary, nullable=False),
    Column("created_at", DateTime, nullable=False),
)

# New table only; existing quotation tables remain untouched.
metadata.create_all(bind=engine, tables=[word_templates])

MAX_TEMPLATE_SIZE = 10 * 1024 * 1024


def get_template(db, template_id):
    row = db.execute(
        select(word_templates).where(
            word_templates.c.id == template_id
        )
    ).mappings().first()

    if row is None:
        raise HTTPException(404, "Word template not found")

    return row


@router.post("/templates")
async def upload_word_template(
    file: UploadFile = File(...),
    template_name: str = Form(...),
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(
        db, user, "quotation_management", "edit"
    )

    name = template_name.strip()

    if not name or len(name) > 200:
        raise HTTPException(400, "Invalid template name")

    if not file.filename or not file.filename.lower().endswith(".docx"):
        raise HTTPException(400, "Only DOCX templates allowed")

    data = await file.read(MAX_TEMPLATE_SIZE + 1)

    if len(data) > MAX_TEMPLATE_SIZE:
        raise HTTPException(413, "Template exceeds 10 MB")

    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if "word/document.xml" not in archive.namelist():
                raise ValueError("Invalid Word document")
            if any(
                item.filename.endswith("vbaProject.bin")
                for item in archive.infolist()
            ):
                raise ValueError("Macro-enabled files not allowed")
    except (zipfile.BadZipFile, ValueError) as exc:
        raise HTTPException(400, str(exc))

    previous_version = db.execute(
        select(word_templates.c.version_no)
        .where(word_templates.c.template_name == name)
        .order_by(word_templates.c.version_no.desc())
        .limit(1)
    ).scalar()

    version = (previous_version or 0) + 1

    result = db.execute(
        word_templates.insert().values(
            template_name=name,
            version_no=version,
            file_name=file.filename,
            file_data=data,
            created_at=datetime.now(),
        )
    )

    db.commit()

    return {
        "id": result.inserted_primary_key[0],
        "template_name": name,
        "version_no": version,
        "message": "Word template uploaded",
    }


@router.get("/templates")
def list_word_templates(
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(
        db, user, "quotation_management", "view"
    )

    rows = db.execute(
        select(
            word_templates.c.id,
            word_templates.c.template_name,
            word_templates.c.version_no,
            word_templates.c.file_name,
            word_templates.c.created_at,
        ).order_by(word_templates.c.id.desc())
    ).mappings().all()

    return [dict(row) for row in rows]


@router.get("/{quotation_id}/docx")
def download_word_quotation(
    quotation_id: int,
    template_id: int,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(
        db, user, "quotation_management", "view"
    )

    quotation = db.query(QuotationMaster).filter(
        QuotationMaster.id == quotation_id,
        QuotationMaster.active.is_(True),
    ).first()

    if quotation is None:
        raise HTTPException(404, "Quotation not found")

    template = get_template(db, template_id)

    try:
        output = build_word_quotation(
            quotation,
            template["file_data"],
        )
    except (ValueError, KeyError) as exc:
        raise HTTPException(400, str(exc))

    safe_no = re.sub(
        r"[^A-Za-z0-9_-]", "_",
        quotation.quotation_no or str(quotation_id)
    )

    filename = f"Dorado_{safe_no}.docx"

    return StreamingResponse(
        io.BytesIO(output),
        media_type=(
            "application/vnd.openxmlformats-officedocument."
            "wordprocessingml.document"
        ),
        headers={
            "Content-Disposition":
                f'attachment; filename="{filename}"'
        },
    )
