from io import BytesIO
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from openpyxl import load_workbook
from sqlalchemy import func
from sqlalchemy.orm import Session

from .database import get_db
from .models import EmployeeMaster, MasterData, MasterType
from .admin_api import get_current_user, require_permission, audit, now_local


router = APIRouter(
    prefix="/api/v1/admin/bulk-import",
    tags=["Dorado CRM Bulk Import"],
)

SUPPORTED_IMPORT_TYPES = {
    "MASTER_DATA",
    "EMPLOYEE",
    "LEAD",
    "CUSTOMER",
}

MASTER_CODE_ALIASES = {
    "code",
    "master_code",
    "id",
    "master_id",
    "type_id",
}

MASTER_NAME_ALIASES = {
    "name",
    "master_name",
    "value",
    "description",
    "title",
}

DISPLAY_ORDER_ALIASES = {
    "display_order",
    "order",
    "sort_order",
    "sequence",
    "sl_no",
    "serial",
}

ACTIVE_ALIASES = {
    "active",
    "is_active",
    "status",
}

DEPARTMENT_ALIASES = {
    "department_id",
    "department",
}


def clean_value(value: Any):
    if value is None:
        return None

    if isinstance(value, str):
        value = value.strip()
        return value if value else None

    return value


def normalize_header(value: Any) -> str:
    if value is None:
        return ""

    text = str(value).strip().lower()

    for old, new in {
        " ": "_",
        "-": "_",
        "/": "_",
        ".": "",
        "(": "",
        ")": "",
        "&": "and",
    }.items():
        text = text.replace(old, new)

    while "__" in text:
        text = text.replace("__", "_")

    return text.strip("_")


def first_value(row: dict[str, Any], aliases: set[str]):
    for key in aliases:
        value = row.get(key)
        if value is not None and str(value).strip():
            return value
    return None


def parse_bool(value: Any, default=True) -> bool:
    if value is None:
        return default

    if isinstance(value, bool):
        return value

    text = str(value).strip().lower()

    if text in {"true", "yes", "y", "1", "active"}:
        return True

    if text in {"false", "no", "n", "0", "inactive"}:
        return False

    return default


def parse_int(value: Any, default=0) -> int:
    if value is None:
        return default

    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def workbook_from_bytes(content: bytes):
    try:
        return load_workbook(
            filename=BytesIO(content),
            read_only=True,
            data_only=True,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid Excel file: {exc}",
        )


def read_sheet(ws, limit: int | None = None):
    rows = ws.iter_rows(values_only=True)

    try:
        first_row = next(rows)
    except StopIteration:
        return [], []

    headers = [
        normalize_header(value) or f"column_{index + 1}"
        for index, value in enumerate(first_row)
    ]

    output = []

    for excel_row_number, values in enumerate(rows, start=2):
        if limit is not None and len(output) >= limit:
            break

        row = {
            headers[index]: clean_value(value)
            for index, value in enumerate(values)
            if index < len(headers)
        }

        if not any(value is not None for value in row.values()):
            continue

        row["_excel_row"] = excel_row_number
        output.append(row)

    return headers, output


def get_workbook_sheet(
    content: bytes,
    sheet_name: str | None,
):
    wb = workbook_from_bytes(content)

    if not wb.sheetnames:
        raise HTTPException(
            status_code=400,
            detail="Workbook has no worksheets",
        )

    selected_sheet = sheet_name or wb.sheetnames[0]

    if selected_sheet not in wb.sheetnames:
        raise HTTPException(
            status_code=400,
            detail=f"Worksheet '{selected_sheet}' not found",
        )

    return wb, selected_sheet


def get_master_type(
    db: Session,
    master_type_id: str | None,
):
    type_id = (master_type_id or "").strip().upper()

    if not type_id:
        raise HTTPException(
            status_code=400,
            detail="Master Type is required",
        )

    row = (
        db.query(MasterType)
        .filter(MasterType.id == type_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Master Type not found",
        )

    return row


def master_row_values(row: dict[str, Any]):
    code = first_value(row, MASTER_CODE_ALIASES)
    name = first_value(row, MASTER_NAME_ALIASES)
    display_order = first_value(row, DISPLAY_ORDER_ALIASES)
    active = first_value(row, ACTIVE_ALIASES)
    department = first_value(row, DEPARTMENT_ALIASES)

    code = str(code).strip().upper() if code is not None else ""
    name = str(name).strip() if name is not None else ""

    return {
        "code": code,
        "name": name,
        "display_order": parse_int(display_order, 0),
        "active": parse_bool(active, True),
        "department_id": (
            str(department).strip()
            if department is not None
            else None
        ),
    }


def validate_master_rows(
    db: Session,
    master_type_id: str,
    rows: list[dict[str, Any]],
):
    results = []
    seen_codes = set()

    for row in rows:
        values = master_row_values(row)
        errors = []

        if not values["code"]:
            errors.append("Code is required")

        if not values["name"]:
            errors.append("Name is required")

        code = values["code"]

        if code:
            if code in seen_codes:
                errors.append("Duplicate code inside uploaded file")
            else:
                seen_codes.add(code)

        existing = None

        if code:
            existing = (
                db.query(MasterData)
                .filter(
                    MasterData.master_type_id == master_type_id,
                    func.upper(MasterData.code) == code.upper(),
                )
                .first()
            )

        action = "ERROR"

        if not errors:
            action = "UPDATE" if existing else "CREATE"

        results.append({
            "excel_row": row.get("_excel_row"),
            **values,
            "action": action,
            "valid": not errors,
            "errors": errors,
        })

    return results


@router.get("/types")
def bulk_import_types(
    user: EmployeeMaster = Depends(get_current_user),
):
    return {
        "import_types": [
            {"id": "MASTER_DATA", "name": "Master Data"},
            {"id": "EMPLOYEE", "name": "Employee / User"},
            {"id": "LEAD", "name": "Lead"},
            {"id": "CUSTOMER", "name": "Customer"},
        ]
    }


@router.get("/master-types")
def bulk_master_types(
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(MasterType)
        .filter(MasterType.active.is_(True))
        .order_by(
            MasterType.display_order,
            MasterType.master_name,
        )
        .all()
    )

    return [
        {
            "id": row.id,
            "name": row.master_name,
        }
        for row in rows
    ]


@router.post("/preview")
async def preview_bulk_import(
    import_type: str = Form(...),
    master_type_id: str | None = Form(None),
    sheet_name: str | None = Form(None),
    file: UploadFile = File(...),
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(db, user, "data_master", "view")

    import_type = import_type.strip().upper()

    if import_type not in SUPPORTED_IMPORT_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Unsupported import type",
        )

    filename = (file.filename or "").lower()

    if not filename.endswith(".xlsx"):
        raise HTTPException(
            status_code=400,
            detail="Only .xlsx files are supported",
        )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=400,
            detail="Uploaded file is empty",
        )

    wb, selected_sheet = get_workbook_sheet(
        content,
        sheet_name,
    )

    headers, rows = read_sheet(
        wb[selected_sheet],
        limit=100,
    )

    validation = None

    if import_type == "MASTER_DATA":
        master_type = get_master_type(
            db,
            master_type_id,
        )

        validation = validate_master_rows(
            db,
            master_type.id,
            rows,
        )

    return {
        "success": True,
        "filename": file.filename,
        "import_type": import_type,
        "master_type_id": (
            master_type_id.strip().upper()
            if master_type_id
            else None
        ),
        "available_sheets": wb.sheetnames,
        "selected_sheet": selected_sheet,
        "headers": headers,
        "rows": rows,
        "validation": validation,
        "preview_rows": len(rows),
    }


@router.post("/import")
async def execute_bulk_import(
    import_type: str = Form(...),
    master_type_id: str | None = Form(None),
    sheet_name: str | None = Form(None),
    update_existing: bool = Form(True),
    file: UploadFile = File(...),
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(db, user, "data_master", "add")

    import_type = import_type.strip().upper()

    if import_type != "MASTER_DATA":
        raise HTTPException(
            status_code=400,
            detail=(
                "Database import for this type is not enabled yet. "
                "Use Preview first."
            ),
        )

    filename = (file.filename or "").lower()

    if not filename.endswith(".xlsx"):
        raise HTTPException(
            status_code=400,
            detail="Only .xlsx files are supported",
        )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=400,
            detail="Uploaded file is empty",
        )

    master_type = get_master_type(
        db,
        master_type_id,
    )

    wb, selected_sheet = get_workbook_sheet(
        content,
        sheet_name,
    )

    _, rows = read_sheet(wb[selected_sheet])

    validation = validate_master_rows(
        db,
        master_type.id,
        rows,
    )

    created = 0
    updated = 0
    skipped = 0
    failed = 0
    results = []

    for item in validation:
        if not item["valid"]:
            failed += 1
            results.append(item)
            continue

        try:
            # Each Excel row gets its own database savepoint.
            # If this row fails, only this row is rolled back.
            with db.begin_nested():
                existing = (
                    db.query(MasterData)
                    .filter(
                        MasterData.master_type_id == master_type.id,
                        func.upper(MasterData.code)
                        == item["code"].upper(),
                    )
                    .first()
                )

                if existing:
                    if not update_existing:
                        skipped += 1
                        results.append({
                            **item,
                            "action": "SKIP",
                        })
                        continue

                    existing.name = item["name"]
                    existing.display_order = item["display_order"]
                    existing.active = item["active"]

                    if item["department_id"] is not None:
                        existing.department_id = item["department_id"]

                    if hasattr(existing, "updated_at"):
                        existing.updated_at = now_local()

                    updated += 1

                    results.append({
                        **item,
                        "action": "UPDATED",
                    })

                else:
                    new_row = MasterData(
                        master_type_id=master_type.id,
                        department_id=item["department_id"],
                        code=item["code"],
                        name=item["name"],
                        display_order=item["display_order"],
                        active=item["active"],
                    )

                    if hasattr(new_row, "created_at"):
                        new_row.created_at = now_local()

                    if hasattr(new_row, "updated_at"):
                        new_row.updated_at = now_local()

                    db.add(new_row)

                    created += 1

                    results.append({
                        **item,
                        "action": "CREATED",
                    })

        except Exception as exc:
            failed += 1

            results.append({
                **item,
                "action": "ERROR",
                "valid": False,
                "errors": [str(exc)],
            })

    try:
        audit(
            db,
            user.id,
            "BULK_IMPORT",
            "data_master",
            "MasterData",
            master_type.id,
            (
                f"File={file.filename}; "
                f"Sheet={selected_sheet}; "
                f"Created={created}; "
                f"Updated={updated}; "
                f"Skipped={skipped}; "
                f"Failed={failed}"
            ),
        )

        db.commit()

    except Exception:
        db.rollback()
        raise

    return {
        "success": failed == 0,
        "import_type": import_type,
        "master_type_id": master_type.id,
        "master_type_name": master_type.master_name,
        "sheet": selected_sheet,
        "summary": {
            "total": len(validation),
            "created": created,
            "updated": updated,
            "skipped": skipped,
            "failed": failed,
        },
        "results": results,
    }

