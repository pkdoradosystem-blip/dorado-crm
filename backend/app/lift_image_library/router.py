from io import BytesIO
import uuid

from fastapi import (
    APIRouter, UploadFile, File, Form,
    HTTPException, Depends
)
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.admin_api import get_current_user, require_permission
from app.models import EmployeeMaster


router = APIRouter(
    prefix="/api/v1/lift-images",
    tags=["Lift Image Library"],
)

ALLOWED_CATEGORIES = {
    "MAIN_LIFT", "GATE", "MACHINE", "CONTROLLER"
}

MAX_UPLOAD_BYTES = 5 * 1024 * 1024


def check_image_view(
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(db, user, "data_master", "view")
    return user


def check_image_upload(
    user: EmployeeMaster = Depends(get_current_user),
):
    role = (user.app_role or "").strip().lower()
    is_admin = (
        user.role_id == "ROL001"
        or role in {"admin", "administrator", "super admin"}
    )
    if not is_admin:
        raise HTTPException(
            status_code=403,
            detail="Admin permission required",
        )
    return user


@router.get("")
def list_images(
    category: str | None = None,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(check_image_view),
):
    if category:
        category = category.upper().strip()

        if category not in ALLOWED_CATEGORIES:
            raise HTTPException(400, "Invalid image category")

        rows = db.execute(
            text("""
                SELECT id, name, category, created_at
                FROM lift_images
                WHERE category = :category
                ORDER BY created_at DESC
            """),
            {"category": category},
        ).mappings().all()
    else:
        rows = db.execute(
            text("""
                SELECT id, name, category, created_at
                FROM lift_images
                ORDER BY created_at DESC
            """)
        ).mappings().all()

    return [
        {
            "id": row["id"],
            "name": row["name"],
            "category": row["category"],
            "url": f'/api/v1/lift-images/{row["id"]}/file',
            "created_at": str(row["created_at"]),
        }
        for row in rows
    ]


@router.post("")
async def upload_image(
    name: str = Form(...),
    category: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(check_image_upload),
):
    category = category.upper().strip()
    name = name.strip()

    if category not in ALLOWED_CATEGORIES:
        raise HTTPException(400, "Invalid image category")

    if not name or len(name) > 255:
        raise HTTPException(400, "Invalid image name")

    data = await file.read(MAX_UPLOAD_BYTES + 1)

    if not data or len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            400, "Image must be between 1 byte and 5 MB"
        )

    try:
        with Image.open(BytesIO(data)) as img:
            img.verify()

        with Image.open(BytesIO(data)) as img:
            if img.format not in {"JPEG", "PNG", "WEBP"}:
                raise ValueError("Unsupported image format")

            img.load()
            img.thumbnail((2000, 2000))

            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGB")

            output = BytesIO()

            if img.mode == "RGBA":
                img.save(output, format="PNG")
                content_type = "image/png"
            else:
                img.save(output, format="JPEG", quality=88)
                content_type = "image/jpeg"

            image_data = output.getvalue()

    except (UnidentifiedImageError, ValueError, OSError):
        raise HTTPException(400, "Invalid image file")

    image_id = uuid.uuid4().hex

    try:
        db.execute(
            text("""
                INSERT INTO lift_images
                (id, name, category, image_data, content_type)
                VALUES (:id, :name, :category, :image_data, :content_type)
            """),
            {
                "id": image_id,
                "name": name,
                "category": category,
                "image_data": image_data,
                "content_type": content_type,
            },
        )
        db.commit()
    except Exception:
        db.rollback()
        raise

    return {
        "id": image_id,
        "name": name,
        "category": category,
        "url": f"/api/v1/lift-images/{image_id}/file",
    }


@router.get("/{image_id}/file")
def get_image(
    image_id: str,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(check_image_view),
):
    row = db.execute(
        text("""
            SELECT image_data, content_type
            FROM lift_images
            WHERE id = :image_id
        """),
        {"image_id": image_id},
    ).mappings().first()

    if row is None:
        raise HTTPException(404, "Image not found")

    return Response(
        content=bytes(row["image_data"]),
        media_type=row["content_type"],
        headers={"Cache-Control": "private, max-age=300"},
    )
