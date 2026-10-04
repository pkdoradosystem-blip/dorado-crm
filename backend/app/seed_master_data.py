from app.database import SessionLocal
from app.models import MasterType, MasterData
from app.admin_api import now_local


MASTER_SEED = {
    "DESIGNATION": {
        "name": "Designation",
        "description": "Employee designation",
        "order": 10,
        "items": [
            ("DIRECTOR", "Director"),
            ("GENERAL_MANAGER", "General Manager"),
            ("MANAGER", "Manager"),
            ("ASST_MANAGER", "Assistant Manager"),
            ("SUPERVISOR", "Supervisor"),
            ("ENGINEER", "Engineer"),
            ("TECHNICIAN", "Technician"),
            ("HELPER", "Helper"),
            ("SALES_EXECUTIVE", "Sales Executive"),
            ("MARKETING_EXECUTIVE", "Marketing Executive"),
            ("LEAD_COLLECTOR", "Lead Collector"),
            ("BACK_OFFICE_EXECUTIVE", "Back Office Executive"),
            ("ACCOUNTS_EXECUTIVE", "Accounts Executive"),
            ("STORE_KEEPER", "Store Keeper"),
            ("OFFICE_ASSISTANT", "Office Assistant"),
        ],
    },

    "EMPLOYEE_TYPE": {
        "name": "Employee Type",
        "description": "Employee engagement type",
        "order": 20,
        "items": [
            ("PERMANENT", "Permanent"),
            ("PROBATION", "Probation"),
            ("CONTRACT", "Contract"),
            ("TRAINEE", "Trainee"),
            ("CONSULTANT", "Consultant"),
        ],
    },

    "GENDER": {
        "name": "Gender",
        "description": "Employee gender",
        "order": 30,
        "items": [
            ("MALE", "Male"),
            ("FEMALE", "Female"),
            ("OTHER", "Other"),
        ],
    },

    "LEAD_SOURCE": {
        "name": "Lead Source",
        "description": "Source of sales lead",
        "order": 40,
        "items": [
            ("DIRECT", "Direct"),
            ("REFERRAL", "Referral"),
            ("WEBSITE", "Website"),
            ("GOOGLE", "Google"),
            ("FACEBOOK", "Facebook"),
            ("INSTAGRAM", "Instagram"),
            ("INDIAMART", "IndiaMART"),
            ("JUSTDIAL", "Justdial"),
            ("EXISTING_CUSTOMER", "Existing Customer"),
            ("PROMOTER", "Promoter"),
            ("ARCHITECT", "Architect"),
            ("CONTRACTOR", "Contractor"),
            ("CONSULTANT", "Consultant"),
            ("SITE_VISIT", "Site Visit"),
            ("OTHER", "Other"),
        ],
    },

    "BUILDING_TYPE": {
        "name": "Building Type",
        "description": "Type of building or project",
        "order": 50,
        "items": [
            ("RESIDENTIAL", "Residential"),
            ("COMMERCIAL", "Commercial"),
            ("HOSPITAL", "Hospital"),
            ("HOTEL", "Hotel"),
            ("SCHOOL_COLLEGE", "School / College"),
            ("INDUSTRIAL", "Industrial"),
            ("GOVERNMENT", "Government"),
            ("SHOPPING_MALL", "Shopping Mall"),
            ("OFFICE", "Office"),
            ("WAREHOUSE", "Warehouse"),
            ("OTHER", "Other"),
        ],
    },

    "LIFT_TYPE": {
        "name": "Lift Type",
        "description": "Elevator application type",
        "order": 60,
        "items": [
            ("PASSENGER", "Passenger Lift"),
            ("GOODS", "Goods Lift"),
            ("GOODS_PASSENGER", "Goods Cum Passenger Lift"),
            ("HOSPITAL", "Hospital Lift"),
            ("HOME", "Home Lift"),
            ("CAPSULE", "Capsule Lift"),
            ("AUTOMOBILE", "Automobile Lift"),
            ("DUMBWAITER", "Dumbwaiter"),
        ],
    },

    "DOOR_TYPE": {
        "name": "Door Type",
        "description": "Elevator door type",
        "order": 70,
        "items": [
            ("MANUAL_COLLAPSIBLE", "Manual Collapsible"),
            ("MANUAL_TELESCOPIC", "Manual Telescopic"),
            ("MANUAL_SWING", "Manual Swing Door"),
            ("AUTO_CENTRE", "Automatic Centre Opening"),
            ("AUTO_TELESCOPIC", "Automatic Telescopic"),
        ],
    },

    "INSTALLATION_TYPE": {
        "name": "Installation Type",
        "description": "Elevator drive / installation arrangement",
        "order": 80,
        "items": [
            ("MR", "Machine Room (MR)"),
            ("MRL", "Machine Room Less (MRL)"),
            ("HYDRAULIC", "Hydraulic"),
        ],
    },

    "REQUIREMENT_TIME": {
        "name": "Requirement Time",
        "description": "Expected customer requirement period",
        "order": 90,
        "items": [
            ("IMMEDIATE", "Immediate"),
            ("WITHIN_1_MONTH", "Within 1 Month"),
            ("1_TO_3_MONTHS", "1–3 Months"),
            ("3_TO_6_MONTHS", "3–6 Months"),
            ("6_TO_12_MONTHS", "6–12 Months"),
            ("ABOVE_12_MONTHS", "Above 12 Months"),
        ],
    },

    "EXECUTIVE_VIEW": {
        "name": "Executive View",
        "description": "Executive assessment of lead",
        "display_order": 9,
        "allow_global": True,
        "values": [
            "Negative",
            "Positive",
            "Customer has Fixed Company",
            "Customer Not Interested",
            "No Person Present",
            "Contact for Next Project",
        ],
    },

    "EXECUTIVE_REMARKS": {
        "name": "Executive Remarks",
        "description": "Standard executive lead remarks",
        "display_order": 10,
        "allow_global": True,
        "values": [
            "Take Some Time",
            "May be Possible",
            "Visit with Senior",
            "Site Stop Now",
            "Site Stop but Open Nearly",
            "Order Given to Others",
            "Please Call Next Week",
        ],
    },

    "LEAD_PRIORITY": {
        "name": "Lead Priority",
        "description": "Sales lead priority",
        "order": 100,
        "items": [
            ("HOT", "Hot"),
            ("WARM", "Warm"),
            ("COLD", "Cold"),
        ],
    },

    "LOST_REASON": {
        "name": "Lost Reason",
        "description": "Reason for lost sales opportunity",
        "order": 110,
        "items": [
            ("HIGH_PRICE", "High Price"),
            ("COMPETITOR", "Competitor"),
            ("NO_RESPONSE", "No Response"),
            ("PROJECT_HOLD", "Project Hold"),
            ("REQUIREMENT_CANCELLED", "Requirement Cancelled"),
            ("FINANCE_ISSUE", "Finance Issue"),
            ("SPECIFICATION_MISMATCH", "Specification Mismatch"),
            ("DELIVERY_TIME", "Delivery Time"),
            ("OTHER", "Other"),
        ],
    },

    "LEAD_STATUS": {
        "name": "Lead Status",
        "description": "Sales pipeline status",
        "order": 120,
        "items": [
            ("NEW", "New Lead"),
            ("CALL_DONE", "Call Done"),
            ("APPOINTMENT", "Appointment Fixed"),
            ("SITE_VISIT", "Site Visit"),
            ("SURVEY", "Survey"),
            ("QUOTATION", "Quotation"),
            ("NEGOTIATION", "Negotiation"),
            ("ORDER_FINALIZED", "Order Finalized"),
            ("ORDER_LOST", "Order Lost"),
        ],
    },

    "AMC_TYPE": {
        "name": "AMC Type",
        "description": "Annual maintenance contract type",
        "order": 130,
        "items": [
            ("COMPREHENSIVE", "Comprehensive AMC"),
            ("SEMI_COMPREHENSIVE", "Semi Comprehensive AMC"),
            ("NON_COMPREHENSIVE", "Non Comprehensive AMC"),
            ("LABOUR_ONLY", "Labour Only"),
        ],
    },

    "COMPLAINT_PRIORITY": {
        "name": "Complaint Priority",
        "description": "Breakdown complaint priority",
        "order": 140,
        "items": [
            ("NORMAL", "Normal"),
            ("URGENT", "Urgent"),
            ("CRITICAL", "Critical"),
        ],
    },
}


def seed_master_data():
    db = SessionLocal()

    try:
        type_created = 0
        type_existing = 0
        data_created = 0
        data_existing = 0

        for master_type_id, config in MASTER_SEED.items():

            master_type = (
                db.query(MasterType)
                .filter(MasterType.id == master_type_id)
                .first()
            )

            if master_type is None:
                master_type = MasterType(
                    id=master_type_id,
                    master_name=config["name"],
                    description=config["description"],
                    allow_global=True,
                    display_order=config["order"],
                    active=True,
                    created_at=now_local(),
                    updated_at=now_local(),
                )

                db.add(master_type)
                db.flush()

                type_created += 1

                print(
                    f"[TYPE CREATED] "
                    f"{master_type_id} - {config['name']}"
                )
            else:
                type_existing += 1

                print(
                    f"[TYPE EXISTS ] "
                    f"{master_type_id} - {config['name']}"
                )

            for display_order, item in enumerate(
                config["items"],
                start=1,
            ):
                code, name = item

                existing = (
                    db.query(MasterData)
                    .filter(
                        MasterData.master_type_id
                        == master_type_id,
                        MasterData.department_id.is_(None),
                        MasterData.code == code,
                    )
                    .first()
                )

                if existing is not None:
                    data_existing += 1

                    print(
                        f"    [SKIP] {code} - {name}"
                    )
                    continue

                row = MasterData(
                    master_type_id=master_type_id,
                    department_id=None,
                    code=code,
                    name=name,
                    display_order=display_order,
                    active=True,
                    created_by="SYSTEM",
                    created_at=now_local(),
                    updated_by="SYSTEM",
                    updated_at=now_local(),
                )

                db.add(row)
                data_created += 1

                print(
                    f"    [ADD ] {code} - {name}"
                )

        db.commit()

        print()
        print("=" * 55)
        print("DORADO CRM MASTER DATA SEED COMPLETED")
        print("=" * 55)
        print(f"Master Types Created : {type_created}")
        print(f"Master Types Existing: {type_existing}")
        print(f"Master Data Created  : {data_created}")
        print(f"Master Data Existing : {data_existing}")
        print("=" * 55)

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


if __name__ == "__main__":
    seed_master_data()