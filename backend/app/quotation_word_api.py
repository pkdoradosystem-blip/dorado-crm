
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
    LargeBinary, DateTime, MetaData, select, Boolean, ForeignKey, UniqueConstraint
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

# Separate configuration tables: do not ALTER existing template/quotation rows.
word_template_types = Table(
    "quotation_word_template_types", metadata,
    Column("template_id", Integer, ForeignKey("quotation_word_templates.id"), primary_key=True),
    Column("quotation_type", String(50), nullable=False, index=True),
)
word_template_defaults = Table(
    "quotation_word_template_defaults", metadata,
    Column("quotation_type", String(50), primary_key=True),
    Column("template_id", Integer, ForeignKey("quotation_word_templates.id"), nullable=False),
)

SUPPORTED_TYPES = {"TRACTION", "GOODS", "HYDRAULIC", "MRL", "MRL_STRUCTURE"}


def normalized_type(value):
    name = str(value or "").strip().upper().replace(" ", "_")
    if name not in SUPPORTED_TYPES:
        raise HTTPException(400, f"Unsupported quotation type: {name}")
    return name


def assign_template_type(db, template_id, quotation_type):
    existing = db.execute(select(word_template_types).where(
        word_template_types.c.template_id == template_id
    )).mappings().first()
    if existing and existing["quotation_type"] != quotation_type:
        raise HTTPException(409, "Template already belongs to another lift type")
    if not existing:
        db.execute(word_template_types.insert().values(
            template_id=template_id, quotation_type=quotation_type
        ))


def set_default(db, quotation_type, template_id):
    existing = db.execute(select(word_template_defaults).where(
        word_template_defaults.c.quotation_type == quotation_type
    )).first()
    if existing:
        db.execute(word_template_defaults.update().where(
            word_template_defaults.c.quotation_type == quotation_type
        ).values(template_id=template_id))
    else:
        db.execute(word_template_defaults.insert().values(
            quotation_type=quotation_type, template_id=template_id
        ))


# New table only; existing quotation tables remain untouched.
metadata.create_all(bind=engine, tables=[word_templates, word_template_types, word_template_defaults])

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
    quotation_type: str = Form("TRACTION"),
    set_as_default: bool = Form(False),
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(
        db, user, "quotation_management", "edit"
    )

    quotation_type = normalized_type(quotation_type)
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

    new_id = result.inserted_primary_key[0]
    assign_template_type(db, new_id, quotation_type)
    if set_as_default:
        set_default(db, quotation_type, new_id)
    db.commit()

    return {
        "id": new_id,
        "quotation_type": quotation_type,
        "is_default": set_as_default,
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
            word_templates.c.id, word_templates.c.template_name,
            word_templates.c.version_no, word_templates.c.file_name,
            word_templates.c.created_at,
            word_template_types.c.quotation_type,
            word_template_defaults.c.template_id.label("default_id"),
        ).select_from(
            word_templates.outerjoin(word_template_types,
                word_templates.c.id == word_template_types.c.template_id)
            .outerjoin(word_template_defaults,
                word_templates.c.id == word_template_defaults.c.template_id)
        ).order_by(word_templates.c.id.desc())
    ).mappings().all()
    return [{**dict(row), "is_default": row["default_id"] == row["id"]}
            for row in rows]


@router.get("/types")
def word_template_types_list(
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(db, user, "quotation_management", "view")
    rows = db.execute(select(word_template_defaults)).mappings().all()
    defaults = {r["quotation_type"]: r["template_id"] for r in rows}
    return [{"quotation_type": t, "default_template_id": defaults.get(t)}
            for t in sorted(SUPPORTED_TYPES)]


@router.post("/templates/{template_id}/default")
def make_default_word_template(
    template_id: int,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(db, user, "quotation_management", "edit")
    get_template(db, template_id)
    row = db.execute(select(word_template_types).where(
        word_template_types.c.template_id == template_id
    )).mappings().first()
    if row is None:
        raise HTTPException(409, "Assign a lift type to this legacy template first")
    set_default(db, row["quotation_type"], template_id)
    db.commit()
    return {"quotation_type": row["quotation_type"], "default_template_id": template_id}


@router.post("/templates/{template_id}/assign-type")
def assign_existing_word_template(
    template_id: int,
    payload: dict,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(db, user, "quotation_management", "edit")
    get_template(db, template_id)
    quotation_type = normalized_type(payload.get("quotation_type"))
    assign_template_type(db, template_id, quotation_type)
    if payload.get("set_as_default") is True:
        set_default(db, quotation_type, template_id)
    db.commit()
    return {"template_id": template_id, "quotation_type": quotation_type}



@router.delete("/templates/{template_id}")
def delete_word_template(
    template_id: int,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(db, user, "quotation_management", "delete")

    template = get_template(db, template_id)

    default_row = db.execute(
        select(word_template_defaults).where(
            word_template_defaults.c.template_id == template_id
        )
    ).first()

    if default_row is not None:
        raise HTTPException(
            409,
            "Cannot delete default template. Assign another default first."
        )

    db.execute(
        word_template_types.delete().where(
            word_template_types.c.template_id == template_id
        )
    )

    db.execute(
        word_templates.delete().where(
            word_templates.c.id == template_id
        )
    )

    db.commit()

    return {
        "message": "Word template deleted successfully",
        "template_id": template_id,
        "template_name": template["template_name"],
    }

@router.get("/{quotation_id}/docx")
def download_word_quotation(
    quotation_id: int,
    template_id: int | None = None,
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

    quotation_type = normalized_type(quotation.quotation_type)
    if template_id is None:
        template_id = db.execute(select(word_template_defaults.c.template_id).where(
            word_template_defaults.c.quotation_type == quotation_type
        )).scalar()
        if template_id is None:
            raise HTTPException(409, f"No default Word template for {quotation_type}")
    else:
        assigned_type = db.execute(select(word_template_types.c.quotation_type).where(
            word_template_types.c.template_id == template_id
        )).scalar()
        if assigned_type != quotation_type:
            raise HTTPException(409, "Template type does not match quotation type")

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
