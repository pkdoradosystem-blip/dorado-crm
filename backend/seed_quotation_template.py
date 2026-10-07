import json

from app.database import SessionLocal
from app.models import QuotationTemplate


TEMPLATE_CODE = "TRACTION_DEFAULT"


sections = {
    "document_title": "QUOTATION",

    "objective": (
        "We are pleased to submit our offer for the proposed elevator "
        "as per the following technical specification and commercial terms."
    ),

    "price_offer_validity": (
        "{{number_of_floor}} {{lift_type}} VVVF Controlled Elevator "
        "{{price_including_gst}}\n"
        "Cabine Model No. :- {{cabin_model_no}}\n"
        "License fee {{license_fee}} Extra. "
        "The Offer is open & valid for your kind acceptance for a period "
        "of {{quotation_validity}} days from the date of proposal given herein. "
        "The price offered shall remain unchanged if job starts within 06 months "
        "from the date of acceptance & advance Payment; thereafter price may be "
        "escalated depending on the situation then prevailing."
    ),

    "terms_of_payment": [
        "30% of contract value to be paid as interest-free advance along with the order as Booking Value.",
        "65% of contract value to be paid before the delivery of complete lift material at your site.",
        "Final 5% of contract value to be paid upon intimation that the installation is ready and before handover of lift."
    ],

    "payment_note": (
        "Payment is receivable only by Cheque/ Online Fund Transfer; "
        "NO Cash Transaction is acceptable."
    ),

    "delivery_period": (
        "The complete lift kit will be supplied to your site within 10 weeks "
        "from the date of finalization/advance payment/completion of site "
        "including the machine room in all respects, whichever is later."
    ),

    "installation": (
        "Complete installation within 8 weeks from Delivery of Lift Kits."
    ),

    "mode_of_payment": (
        "All payments are to be made through approved company banking channels. "
        "Company payment details can be maintained from the quotation template settings."
    ),

    "customer_obligations": [
        "Finalization of the drawing/ schematic layout within 2 weeks from date of order.",
        "Completion of civil works including plastering & whitewash of the legally constructed elevator hoist way, pit & machine room & waterproofing of the pit, at least 3 weeks before contractual due date of elevator complete installation.",
        "Providing required electrical power supply to the hoist way and machine room before contractual due date of elevator delivery.",
        "Obtaining necessary statutory permission applicable to the installation.",
        "Clearing all payments as & when they become due, before the work proceeds to the next phase.",
        "Scaffolding work including material."
    ],

    "our_obligations": [
        "Helping Customer finalize the drawing / schematic layout.",
        "Advising customer on the civil works portion of the elevator hoist way, pit & machine room.",
        "Helping customer in obtaining necessary permission by providing the manufacturer's data.",
        "Delivering the complete elevator as per defined specifications."
    ],

    "warranty": "",
    "service_terms": "",
    "change_of_specification": "",
    "cancellation": "",
    "arbitration": "",
    "jurisdiction": "",
    "other_terms_conditions": "",

    "signature_representative": "Signature of Representative",
    "signature_customer": "Signature of Customer"
}


placeholder_map = {
    "{{quotation_no}}": "quotation_no",
    "{{quotation_date}}": "quotation_date",

    "{{customer_name}}": "customer_name",
    "{{construction_building_name}}": "construction_building_name",
    "{{office_address}}": "office_address",
    "{{site_address}}": "site_address",
    "{{location}}": "location",
    "{{mobile}}": "mobile",

    "{{lift_type}}": "technical_data.lift_type",
    "{{number_of_floor}}": "technical_data.number_of_floor",
    "{{no_of_stops}}": "technical_data.no_of_stops",
    "{{no_of_opening}}": "technical_data.no_of_opening",
    "{{opening_side}}": "technical_data.opening_side",
    "{{opening_side_details}}": "technical_data.opening_side_details",
    "{{ard_required}}": "technical_data.ard_required",
    "{{entrance_opening}}": "technical_data.entrance_opening",
    "{{total_height}}": "technical_data.total_height",
    "{{landing_door_type}}": "technical_data.landing_door_type",
    "{{car_door_type}}": "technical_data.car_door_type",
    "{{door_operation}}": "technical_data.door_operation",
    "{{car_enclosure}}": "technical_data.car_enclosure",
    "{{overhead}}": "technical_data.overhead",
    "{{shaft_width}}": "technical_data.shaft_width",
    "{{shaft_depth}}": "technical_data.shaft_depth",
    "{{person_capacity}}": "technical_data.person_capacity",

    "{{price_including_gst}}": "commercial_data.price_including_gst",
    "{{license_fee}}": "commercial_data.license_fee",
    "{{quotation_validity}}": "commercial_data.quotation_validity",
    "{{cabin_model_no}}": "commercial_data.cabin_model_no",
    "{{extra_payment}}": "commercial_data.extra_payment"
}


layout_config = {
    "format": "DORADO_QUOTATION_V1",
    "page_size": "A4",
    "quotation_type": "TRACTION",
    "sections": [
        "document_title",
        "objective",
        "technical_specification",
        "price_offer_validity",
        "terms_of_payment",
        "payment_note",
        "delivery_period",
        "installation",
        "mode_of_payment",
        "customer_obligations",
        "our_obligations",
        "warranty",
        "service_terms",
        "change_of_specification",
        "cancellation",
        "arbitration",
        "jurisdiction",
        "other_terms_conditions",
        "signatures"
    ],
    "placeholder_map": placeholder_map
}


def seed():
    db = SessionLocal()

    try:
        existing = (
            db.query(QuotationTemplate)
            .filter(
                QuotationTemplate.template_code == TEMPLATE_CODE,
                QuotationTemplate.version_no == 1,
            )
            .first()
        )

        if existing:
            print("TRACTION DEFAULT TEMPLATE V1 ALREADY EXISTS")
            print(f"Template ID: {existing.id}")
            return

        old_defaults = (
            db.query(QuotationTemplate)
            .filter(
                QuotationTemplate.quotation_type == "TRACTION",
                QuotationTemplate.is_default.is_(True),
            )
            .all()
        )

        for row in old_defaults:
            row.is_default = False

        template = QuotationTemplate(
            template_code=TEMPLATE_CODE,
            template_name="Traction Default Template",
            quotation_type="TRACTION",
            version_no=1,
            template_content=json.dumps(
                sections,
                ensure_ascii=False,
                indent=2,
            ),
            layout_config=json.dumps(
                layout_config,
                ensure_ascii=False,
                indent=2,
            ),
            is_default=True,
            active=True,
        )

        db.add(template)
        db.commit()
        db.refresh(template)

        print("TRACTION DEFAULT TEMPLATE V1 CREATED")
        print(f"Template ID: {template.id}")
        print(f"Template Code: {template.template_code}")
        print(f"Version: {template.version_no}")
        print(f"Default: {template.is_default}")

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


if __name__ == "__main__":
    seed()
