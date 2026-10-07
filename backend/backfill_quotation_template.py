from app.database import SessionLocal
from app.models import QuotationMaster, QuotationTemplate


def backfill():
    db = SessionLocal()

    try:
        template = (
            db.query(QuotationTemplate)
            .filter(
                QuotationTemplate.template_code ==
                "TRACTION_DEFAULT",
                QuotationTemplate.version_no == 1,
            )
            .first()
        )

        if template is None:
            raise RuntimeError(
                "TRACTION_DEFAULT V1 template not found"
            )

        rows = (
            db.query(QuotationMaster)
            .filter(
                QuotationMaster.quotation_type ==
                "TRACTION"
            )
            .all()
        )

        updated = 0

        for quotation in rows:
            if not quotation.template_code:
                quotation.template_code = (
                    template.template_code
                )

            if not quotation.template_version:
                quotation.template_version = (
                    template.version_no
                )

            updated += 1

        db.commit()

        print("QUOTATION TEMPLATE BACKFILL PASSED")
        print(f"Traction quotations checked: {len(rows)}")
        print(f"Template: {template.template_code}")
        print(f"Version: {template.version_no}")

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


if __name__ == "__main__":
    backfill()
