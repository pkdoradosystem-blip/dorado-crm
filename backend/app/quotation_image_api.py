from fastapi import APIRouter

router = APIRouter(
    prefix="/api/v1/quotations",
    tags=["Quotation Images"],
)


from fastapi import Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.database import get_db
from app.admin_api import get_current_user, require_permission
from app.models import EmployeeMaster, QuotationMaster

@router.get("/{quotation_id}/images")
def get_quotation_images(
    quotation_id: int,
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

    rows = db.execute(
        text("""
            SELECT image_id, category, display_order
            FROM quotation_images
            WHERE quotation_id = :qid
            ORDER BY display_order, id
        """),
        {"qid": quotation_id},
    ).mappings().all()

    return {
        "quotation_id": quotation_id,
        "images": [dict(row) for row in rows],
    }


import sqlite3
from pydantic import BaseModel

class QuotationImageItem(BaseModel):
    image_id: str
    category: str

class QuotationImagesPayload(BaseModel):
    images: list[QuotationImageItem]

@router.put("/{quotation_id}/images")
def save_quotation_images(
    quotation_id: int,
    payload: QuotationImagesPayload,
    db: Session = Depends(get_db),
    user: EmployeeMaster = Depends(get_current_user),
):
    require_permission(
        db, user, "quotation_management", "edit"
    )

    quotation = db.query(QuotationMaster).filter(
        QuotationMaster.id == quotation_id,
        QuotationMaster.active.is_(True),
    ).first()

    if quotation is None:
        raise HTTPException(404, "Quotation not found")

    allowed = {
        "MAIN_LIFT", "GATE", "MACHINE", "CONTROLLER"
    }

    images = payload.images
    categories = [x.category for x in images]

    if (
        len(images) > 4
        or len(categories) != len(set(categories))
        or any(x.category not in allowed for x in images)
    ):
        raise HTTPException(422, "Invalid picture selection")

    # Validate selected images using the CRM database.
    # Image bytes are stored in lift_images.image_data.
    for item in images:
        row = db.execute(
            text("""
                SELECT category
                FROM lift_images
                WHERE id = :image_id
            """),
            {"image_id": item.image_id},
        ).mappings().first()

        if row is None or row["category"] != item.category:
            raise HTTPException(
                status_code=422,
                detail="Invalid image ID/category",
            )

    try:
        db.execute(
            text("DELETE FROM quotation_images WHERE quotation_id=:qid"),
            {"qid": quotation_id},
        )

        for index, item in enumerate(images, 1):
            db.execute(
                text("""
                    INSERT INTO quotation_images
                    (quotation_id, image_id, category, display_order)
                    VALUES (:qid, :iid, :cat, :ord)
                """),
                {
                    "qid": quotation_id,
                    "iid": item.image_id,
                    "cat": item.category,
                    "ord": index,
                },
            )

        db.commit()
    except Exception:
        db.rollback()
        raise

    return {
        "quotation_id": quotation_id,
        "saved": len(images),
        "message": "Quotation images saved",
    }
