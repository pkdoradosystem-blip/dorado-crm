from .bulk_import_api import router as bulk_import_router
from datetime import datetime
from typing import Any
import uuid
import json

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from .database import Base, engine, get_db, SessionLocal
from .admin_api import router as admin_router, sync_foundation_data
from .models import (
    Lead,
    LeadActivity,
    QuotationMaster,
    QuotationLiftItem,
    EmployeeMaster,
    MasterData,
    LeadSourceMaster,
    BuildingTypeMaster,
    LiftTypeMaster,
    RequirementTimeMaster,
    LeadStatusMaster,
    LeadPriorityMaster,
    LostReasonMaster,
    NegotiationStatusMaster,
)

Base.metadata.create_all(bind=engine)


def ensure_employee_reference_columns():
    """Small safe migration for existing SQLite/PostgreSQL databases."""
    inspector = inspect(engine)
    existing = {column["name"] for column in inspector.get_columns("employee_master")}
    required = {
        "department_id": "VARCHAR(30)",
        "role_id": "VARCHAR(30)",
        "reporting_manager_id": "VARCHAR(30)",
    }
    with engine.begin() as connection:
        for column_name, sql_type in required.items():
            if column_name not in existing:
                connection.execute(text(
                    f"ALTER TABLE employee_master ADD COLUMN {column_name} {sql_type}"
                ))


ensure_employee_reference_columns()

# Seed/sync only structural master data. Existing employees, leads and transactions are preserved.
with SessionLocal() as _startup_db:
    sync_foundation_data(_startup_db)

app = FastAPI(
    title="Dorado CRM API",
    version="2.0.0",
)

app.include_router(admin_router)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MENUS = [
    {
        "id": "sales_marketing",
        "title": "Sales & Marketing",
        "subtitle": "Lead, follow-up, target & marketing",
        "icon": "sales",
        "routeType": "submenu",
        "children": [
            {
                "id": "lead_entry",
                "title": "Lead Entry",
                "subtitle": "Create a new sales lead",
                "icon": "add",
                "routeType": "form",
                "formCode": "lead_entry",
                "children": [],
            },
            {
                "id": "all_leads",
                "title": "All Leads",
                "subtitle": "View & search all sales leads",
                "icon": "list",
                "routeType": "page",
                "formCode": "",
                "children": [],
            },
            {
                "id": "lead_update",
                "title": "Lead Update",
                "subtitle": "Update existing leads",
                "icon": "edit",
                "routeType": "page",
                "formCode": "",
                "children": [],
            },
            {
                "id": "follow_up",
                "title": "Follow-up",
                "subtitle": "Monthly, missed & custom follow-up",
                "icon": "followup",
                "routeType": "page",
                "formCode": "",
                "children": [],
            },
            {
                "id": "targets",
                "title": "Targets",
                "subtitle": "Sales target & achievement",
                "icon": "target",
                "routeType": "page",
                "formCode": "",
                "children": [],
            },
            {
                "id": "marketing_reports",
                "title": "Marketing Reports",
                "subtitle": "Pipeline activity reports",
                "icon": "report",
                "routeType": "page",
                "formCode": "",
                "children": [],
            },
        ],
    },

    {
        "id": "new_installation",
        "title": "New Installation",
        "subtitle": "Installation projects & progress",
        "icon": "installation",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "repair_modification",
        "title": "Repair & Modification",
        "subtitle": "Repair and modernization jobs",
        "icon": "repair",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "amc_service",
        "title": "AMC & Service",
        "subtitle": "AMC, PM & breakdown management",
        "icon": "service",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "production",
        "title": "Production",
        "subtitle": "Production & material management",
        "icon": "production",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "accounts_official",
        "title": "Accounts & Official",
        "subtitle": "Accounts and official activities",
        "icon": "accounts",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "back_office",
        "title": "Back Office",
        "subtitle": "Back office operations",
        "icon": "office",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "performance",
        "title": "Performance",
        "subtitle": "Employee performance",
        "icon": "performance",
        "routeType": "submenu",
        "children": [],
    },

    {
        "id": "reports",
        "title": "Reports",
        "subtitle": "Business reports",
        "icon": "report",
        "routeType": "submenu",
        "children": [],
    },
]


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

def _iso(value):
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def lead_to_dict(lead: Lead) -> dict[str, Any]:
    return {
        column.name: _iso(getattr(lead, column.name))
        for column in Lead.__table__.columns
    }


def master_to_dict(item) -> dict[str, Any]:
    return {
        column.name: _iso(getattr(item, column.name))
        for column in item.__table__.columns
    }


def parse_datetime(value):
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            try:
                return datetime.strptime(text[:10], "%Y-%m-%d")
            except ValueError:
                return None
    return None


DATE_FIELDS = {
    "timestamp",
    "lead_date",
    "appointment_date",
    "site_visit_date",
    "survey_date",
    "quotation_date",
    "negotiation_date",
    "order_date",
    "lost_date",
    "last_call",
    "follow_up_date",
    "revisit_date",
    "expected_close_date",
    "created_at",
    "updated_at",
}


def active_master_values(db: Session, model, value_field: str):
    rows = (
        db.query(model)
        .filter(model.active.is_(True))
        .all()
    )
    return [
        {
            "id": row.id,
            "value": getattr(row, value_field),
            "label": getattr(row, value_field),
        }
        for row in rows
    ]


def common_master_options(db: Session, master_type_id: str):
    # Support both historical IDs such as "EXECUTIVE VIEW"
    # and standard IDs such as "EXECUTIVE_VIEW".
    requested = str(master_type_id or "").strip().upper()

    candidate_ids = {
        requested,
        requested.replace("_", " "),
        requested.replace(" ", "_"),
    }

    rows = (
        db.query(MasterData)
        .filter(
            MasterData.master_type_id.in_(candidate_ids),
            MasterData.active.is_(True),
        )
        .order_by(
            MasterData.display_order,
            MasterData.name,
        )
        .all()
    )

    return [
        {
            "id": row.id,
            "value": row.name,
            "label": row.name,
        }
        for row in rows
        if row.name and str(row.name).strip()
    ]


def employee_options(db: Session, designation_keyword: str | None = None):
    query = db.query(EmployeeMaster).filter(EmployeeMaster.active.is_(True))
    rows = query.order_by(EmployeeMaster.employee_name).all()

    if designation_keyword:
        keyword = designation_keyword.lower()
        rows = [
            row for row in rows
            if keyword in (row.designation or "").lower()
        ]

    return [
        {
            "id": row.id,
            "value": row.employee_name,
            "label": row.employee_name,
            "designation": row.designation,
            "department": row.department,
            "app_role": row.app_role,
            "reporting_manager": row.reporting_manager,
        }
        for row in rows
    ]


def assigned_marketing_head(db: Session, collector_name: str | None):
    if not collector_name:
        return None
    collector = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.employee_name == collector_name)
        .first()
    )
    if collector is None:
        return None
    return collector.reporting_manager or None


def activity_to_dict(activity: LeadActivity) -> dict[str, Any]:
    return {
        column.name: _iso(getattr(activity, column.name))
        for column in LeadActivity.__table__.columns
    }


def get_next_display_lead_id(db: Session) -> str:
    last = db.query(Lead).order_by(Lead.id.desc()).first()
    next_number = 1 if last is None else int(last.id) + 1
    return f"LD{next_number:03d}"


def get_lead_or_404(db: Session, lead_id: int) -> Lead:
    lead = db.query(Lead).filter(Lead.id == lead_id).first()
    if lead is None:
        raise HTTPException(status_code=404, detail="Lead not found")
    return lead


# ---------------------------------------------------------
# HEALTH
# ---------------------------------------------------------

@app.get("/health")
def health():
    return {
        "status": "ok",
        "application": "Dorado CRM API",
        "database": engine.url.get_backend_name(),
    }


# ---------------------------------------------------------
# MENU API
# ---------------------------------------------------------

@app.get("/api/v1/menus")
def get_menus():
    # Keep the base menu definition unchanged.
    # Add Quotation to Sales & Marketing if it is not
    # already present.
    for menu in MENUS:
        if str(menu.get("title", "")).strip().lower() != "sales & marketing":
            continue

        children = menu.setdefault("children", [])

        quotation_exists = any(
            str(child.get("title", "")).strip().lower()
            in {"quotation", "quotations"}
            for child in children
        )

        if not quotation_exists:
            children.append(
                {
                    "id": "quotation",
                    "title": "Quotation",
                    "subtitle": "Create & manage customer quotations",
                    "icon": "quotation",
                    "routeType": "page",
                    "routeName": "quotation",
                    "children": [],
                }
            )

        break

    return MENUS


# ---------------------------------------------------------
# MASTER APIs
# ---------------------------------------------------------

@app.get("/api/v1/masters/employees")
def get_employees(db: Session = Depends(get_db)):
    return employee_options(db)


@app.get("/api/v1/masters/lead-collectors")
def get_lead_collectors(db: Session = Depends(get_db)):
    return employee_options(db, "lead collector")


@app.get("/api/v1/masters/executives")
def get_executives(db: Session = Depends(get_db)):
    return employee_options(db, "lead collector")


@app.get("/api/v1/masters/marketing-heads")
def get_marketing_heads(db: Session = Depends(get_db)):
    return employee_options(db, "marketing head")


@app.get("/api/v1/masters/lead-sources")
def get_lead_sources(db: Session = Depends(get_db)):
    return active_master_values(db, LeadSourceMaster, "lead_source")


@app.get("/api/v1/masters/building-types")
def get_building_types(db: Session = Depends(get_db)):
    return active_master_values(db, BuildingTypeMaster, "building_type")


@app.get("/api/v1/masters/lift-types")
def get_lift_types(db: Session = Depends(get_db)):
    return active_master_values(db, LiftTypeMaster, "lift_type")


@app.get("/api/v1/masters/requirement-times")
def get_requirement_times(db: Session = Depends(get_db)):
    return active_master_values(db, RequirementTimeMaster, "requirement_time")


@app.get("/api/v1/masters/lead-statuses")
def get_lead_statuses(db: Session = Depends(get_db)):
    return active_master_values(db, LeadStatusMaster, "lead_status")


@app.get("/api/v1/masters/lead-priorities")
def get_lead_priorities(db: Session = Depends(get_db)):
    return active_master_values(db, LeadPriorityMaster, "lead_priority")


@app.get("/api/v1/masters/lost-reasons")
def get_lost_reasons(db: Session = Depends(get_db)):
    return active_master_values(db, LostReasonMaster, "lost_reason")


@app.get("/api/v1/masters/negotiation-statuses")
def get_negotiation_statuses(db: Session = Depends(get_db)):
    return active_master_values(db, NegotiationStatusMaster, "negotiation_status")


# ---------------------------------------------------------
# DYNAMIC LEAD ENTRY FORM
# ---------------------------------------------------------

@app.get("/api/v1/forms/{code}")
def get_form(code: str, db: Session = Depends(get_db)):
    if code != "lead_entry":
        raise HTTPException(status_code=404, detail="Form not found")

    return {
        "code": "lead_entry",
        "title": "Lead Entry",
        "submitEndpoint": "/api/v1/data/leads",
        "fields": [
            {"key": "lead_date", "label": "Lead Date", "type": "date", "required": True},
            {"key": "lead_collector_name", "label": "Executive Name", "type": "dropdown", "required": True,
             "options": [
                 x["value"]
                 for x in employee_options(db)
                 if (
                     "marketing" in str(x.get("department") or "").lower()
                     or "sales" in str(x.get("department") or "").lower()
                 )
             ]},
            {"key": "lead_source", "label": "Lead Source", "type": "dropdown", "required": True,
             "options": [x["value"] for x in common_master_options(db, "LEAD_SOURCE")]},
            {"key": "customer_name", "label": "Customer Name", "type": "text", "required": True},
            {"key": "mobile", "label": "Mobile", "type": "phone", "required": True},
            {
            "key": "construction_building_name",
            "label": "Construction / Building Name",
            "type": "text",
            "required": True,
        },
        {
            "key": "office_address",
            "label": "Office Address",
            "type": "textarea",
            "required": True,
        },
        {
            "key": "site_address",
            "label": "Site Address",
            "type": "textarea",
            "required": False,
        },
        {"key": "location", "label": "Location", "type": "map", "required": True},
            {"key": "building_type", "label": "Building Type", "type": "dropdown", "required": False,
             "options": [x["value"] for x in common_master_options(db, "BUILDING_TYPE")]},
            {"key": "lift_type", "label": "Lift Type", "type": "dropdown", "required": False,
             "options": [x["value"] for x in common_master_options(db, "LIFT_TYPE")]},
            {"key": "collector_view", "label": "Executive View", "type": "dropdown", "required": True,
             "options": [x["value"] for x in common_master_options(db, "EXECUTIVE_VIEW")]},
            {"key": "collector_remarks", "label": "Executive Remarks", "type": "dropdown", "required": True,
             "options": [x["value"] for x in common_master_options(db, "EXECUTIVE_REMARKS")]},
            {"key": "follow_up_date", "label": "Follow-up Date", "type": "date", "required": False},
            {"key": "image_1", "label": "Image 1", "type": "image", "required": False},
            {"key": "image_2", "label": "Image 2", "type": "image", "required": False},
            {"key": "image_3", "label": "Image 3", "type": "image", "required": False},
            {"key": "marketing_head", "label": "Assigned Marketing Head", "type": "auto", "required": False, "readOnly": True},
            {"key": "lead_priority", "label": "Lead Priority", "type": "dropdown", "required": False,
             "options": [x["value"] for x in common_master_options(db, "LEAD_PRIORITY")]},
        ],
    }


@app.get("/api/v1/assignment/marketing-head")
def get_assigned_marketing_head(collector_name: str, db: Session = Depends(get_db)):
    head = assigned_marketing_head(db, collector_name)
    return {"lead_collector_name": collector_name, "marketing_head": head}


# ---------------------------------------------------------
# LEAD CRUD
# ---------------------------------------------------------

@app.get("/api/v1/data/leads")
def get_leads(db: Session = Depends(get_db)):
    leads = db.query(Lead).order_by(Lead.id.desc()).all()
    return [lead_to_dict(lead) for lead in leads]


@app.post("/api/v1/data/leads")
def create_lead(payload: dict[str, Any], db: Session = Depends(get_db)):
    customer_name = str(payload.get("customer_name", "")).strip()
    mobile = str(payload.get("mobile", "")).strip()

    if not customer_name:
        raise HTTPException(status_code=400, detail="Customer Name is required")
    if not mobile:
        raise HTTPException(status_code=400, detail="Mobile Number is required")

    # Manual Lead Entry must contain at least one site/building image.
    image_values = [
        payload.get("image_1"),
        payload.get("image_2"),
        payload.get("image_3"),
    ]

    if not any(
        value is not None and str(value).strip()
        for value in image_values
    ):
        raise HTTPException(
            status_code=400,
            detail="Please add at least one site/building image",
        )

    now = datetime.now()
    display_id = get_next_display_lead_id(db)

    lead = Lead(
        timestamp=now,
        lead_date=parse_datetime(payload.get("lead_date")) or now,
        lead_key=str(uuid.uuid4()),
        lead_id=display_id,

        lead_collector_name=payload.get("lead_collector_name"),
        collector_view=payload.get("collector_view"),
        collector_remarks=payload.get("collector_remarks"),
        lead_source=payload.get("lead_source"),
        customer_name=customer_name,
        construction_building_name=payload.get("construction_building_name"),
        mobile=mobile,
        office_address=payload.get("office_address"),
        site_address=payload.get("site_address"),
        location=payload.get("location"),
        latitude=payload.get("latitude"),
        longitude=payload.get("longitude"),
        building_type=payload.get("building_type"),
        lift_type=payload.get("lift_type"),
        requirement_time=payload.get("requirement_time"),

        call_done=bool(payload.get("call_done", False)),
        appointment_fixed=bool(payload.get("appointment_fixed", False)),
        appointment_date=parse_datetime(payload.get("appointment_date")),
        site_visit_done=bool(payload.get("site_visit_done", False)),
        site_visit_date=parse_datetime(payload.get("site_visit_date")),
        survey_done=bool(payload.get("survey_done", False)),
        survey_date=parse_datetime(payload.get("survey_date")),
        quotation_given=bool(payload.get("quotation_given", False)),
        quotation_date=parse_datetime(payload.get("quotation_date")),

        negotiation_status=payload.get("negotiation_status"),
        negotiation_date=parse_datetime(payload.get("negotiation_date")),
        negotiation_done=bool(payload.get("negotiation_done", False)),

        order_finalized=bool(payload.get("order_finalized", False)),
        order_date=parse_datetime(payload.get("order_date")),
        order_value=payload.get("order_value"),
        order_lost=bool(payload.get("order_lost", False)),
        lost_date=parse_datetime(payload.get("lost_date")),

        lead_status=payload.get("lead_status") or "New Lead",
        remarks=payload.get("remarks"),
        new_remarks=payload.get("new_remarks"),
        last_call=parse_datetime(payload.get("last_call")),
        follow_up_date=parse_datetime(payload.get("follow_up_date")),
        revisit_date=parse_datetime(payload.get("revisit_date")),
        over_phone=bool(payload.get("over_phone", False)),
        score=payload.get("score"),
        duplicate_check=payload.get("duplicate_check"),

        image_1=payload.get("image_1"),
        image_2=payload.get("image_2"),
        image_3=payload.get("image_3"),

        marketing_head=assigned_marketing_head(db, payload.get("lead_collector_name")) or payload.get("marketing_head"),
        lead_priority=payload.get("lead_priority"),
        expected_order_value=payload.get("expected_order_value"),
        expected_close_date=parse_datetime(payload.get("expected_close_date")),
        lost_reason=payload.get("lost_reason"),
        created_by=payload.get("created_by"),
        created_at=now,
        updated_at=now,
        active=bool(payload.get("active", True)),
    )

    db.add(lead)
    db.commit()
    db.refresh(lead)

    return lead_to_dict(lead)


@app.get("/api/v1/data/leads/{lead_id}")
def get_lead(lead_id: int, db: Session = Depends(get_db)):
    return lead_to_dict(get_lead_or_404(db, lead_id))


@app.put("/api/v1/data/leads/{lead_id}")
def update_lead(
    lead_id: int,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
):
    lead = get_lead_or_404(db, lead_id)

    protected_fields = {
        "id",
        "lead_key",
        "lead_id",
        "timestamp",
        "created_at",
    }

    valid_columns = {column.name for column in Lead.__table__.columns}

    for key, value in payload.items():
        if key in protected_fields or key not in valid_columns:
            continue

        if key in DATE_FIELDS:
            value = parse_datetime(value)

        setattr(lead, key, value)

    lead.updated_at = datetime.now()

    db.commit()
    db.refresh(lead)

    return lead_to_dict(lead)


@app.delete("/api/v1/data/leads/{lead_id}")
def delete_lead(lead_id: int, db: Session = Depends(get_db)):
    lead = get_lead_or_404(db, lead_id)
    db.delete(lead)
    db.commit()

    return {
        "success": True,
        "message": "Lead deleted successfully",
    }




# ---------------------------------------------------------
# QUOTATION FORM DEFINITIONS
# ---------------------------------------------------------

QUOTATION_TYPES = [
    {
        "id": "TRACTION",
        "name": "Traction Lift",
    },
    {
        "id": "GOODS",
        "name": "Goods Lift",
    },
    {
        "id": "HYDRAULIC",
        "name": "Hydraulic Lift",
    },
    {
        "id": "MRL_1_PHASE",
        "name": "MRL Lift - 1 Phase",
    },
    {
        "id": "MRL_3_PHASE",
        "name": "MRL Lift - 3 Phase",
    },
    {
        "id": "MRL_STRUCTURE",
        "name": "MRL with Structure / Civil / Covering",
    },
]


TRACTION_QUOTATION_FIELDS = [
    {
        "key": "lift_type",
        "label": "Lift Type",
        "type": "dropdown",
        "master_type": "LIFT_TYPE",
        "required": True,
    },
    {
        "key": "number_of_floor",
        "label": "Number of Floor",
        "type": "dropdown",
        "master_type": "NO_OF_FLOOR",
        "required": True,
    },
    {
        "key": "no_of_stops",
        "label": "No of Stops",
        "type": "number",
        "required": True,
    },
    {
        "key": "no_of_opening",
        "label": "No of Opening",
        "type": "number",
        "required": True,
    },
    {
        "key": "opening_side",
        "label": "Opening Side",
        "type": "choice",
        "options": ["All Same Side", "Different Side"],
        "required": True,
    },
    {
        "key": "opening_side_details",
        "label": "Opening Side Details",
        "type": "text",
        "required": False,
    },
    {
        "key": "ard_required",
        "label": "ARD Required",
        "type": "choice",
        "options": ["YES", "NO"],
        "required": True,
    },
    {
        "key": "entrance_opening",
        "label": "Entrance Opening",
        "type": "dropdown",
        "master_type": "ENTRANCE_OPENING",
        "required": True,
    },
    {
        "key": "total_height",
        "label": "Total Height",
        "type": "number",
        "required": True,
    },
    {
        "key": "landing_door_type",
        "label": "Landing Door Type",
        "type": "dropdown",
        "master_type": "LANDING_DOOR_TYPE",
        "required": True,
    },
    {
        "key": "car_door_type",
        "label": "Car Door Type",
        "type": "dropdown",
        "master_type": "CAR_DOOR_TYPE",
        "required": True,
    },
    {
        "key": "door_operation",
        "label": "Door Operation",
        "type": "choice",
        "options": ["Manual", "Auto"],
        "required": True,
    },
    {
        "key": "car_enclosure",
        "label": "Car Enclosure",
        "type": "dropdown",
        "master_type": "CAR_ENCLOSURE",
        "required": True,
    },
    {
        "key": "overhead",
        "label": "Overhead",
        "type": "dropdown",
        "master_type": "OVERHEAD",
        "required": True,
    },
    {
        "key": "shaft_width",
        "label": "Shaft Width",
        "type": "number",
        "required": False,
    },
    {
        "key": "shaft_depth",
        "label": "Shaft Depth",
        "type": "number",
        "required": False,
    },
    {
        "key": "person_capacity",
        "label": "Person Capacity",
        "type": "dropdown",
        "master_type": "PERSON_CAPACITY",
        "required": True,
    },

    # Commercial inputs from current quotation form.
    {
        "key": "price_including_gst",
        "label": "Price including GST",
        "type": "number",
        "required": True,
    },
    {
        "key": "license_fee",
        "label": "License Fee",
        "type": "dropdown",
        "master_type": "LICENSE_FEE",
        "required": True,
    },
    {
        "key": "quotation_validity",
        "label": "Quotation Validity",
        "type": "dropdown",
        "master_type": "QUOTATION_VALIDITY",
        "required": True,
    },
    {
        "key": "cabin_model_no",
        "label": "Cabine Model No.",
        "type": "text",
        "required": False,
    },
    {
        "key": "extra_payment",
        "label": "Extra Payment",
        "type": "text",
        "required": False,
    },
]


def quotation_fields_for_type(
    quotation_type: str,
):
    quotation_type = str(
        quotation_type or ""
    ).strip().upper()

    # Traction is the first fully configured format.
    if quotation_type == "TRACTION":
        return TRACTION_QUOTATION_FIELDS

    # Other formats will receive their own technical
    # definitions without changing the quotation engine.
    return []


@app.get("/api/v1/quotation-types")
def get_quotation_types():
    return QUOTATION_TYPES


@app.get("/api/v1/quotation-form-definition")
def get_quotation_form_definition(
    quotation_type: str = "TRACTION",
    db: Session = Depends(get_db),
):
    fields = quotation_fields_for_type(
        quotation_type
    )

    if not fields:
        raise HTTPException(
            status_code=400,
            detail=(
                "Quotation format is not configured yet"
            ),
        )

    result = []

    for definition in fields:
        field = dict(definition)

        master_type = field.get(
            "master_type"
        )

        if master_type:
            field["options"] = (
                common_master_options(
                    db,
                    master_type,
                )
            )

        result.append(field)

    return {
        "quotation_type": quotation_type,
        "fields": result,
    }


# ---------------------------------------------------------
# SALES QUOTATION
# ---------------------------------------------------------


def quotation_to_dict(
    quotation: QuotationMaster,
    db: Session,
) -> dict[str, Any]:

    data = {
        column.name: _iso(getattr(quotation, column.name))
        for column in QuotationMaster.__table__.columns
    }

    items = (
        db.query(QuotationLiftItem)
        .filter(
            QuotationLiftItem.quotation_id == quotation.id,
            QuotationLiftItem.active.is_(True),
        )
        .order_by(
            QuotationLiftItem.display_order,
            QuotationLiftItem.item_no,
            QuotationLiftItem.id,
        )
        .all()
    )

    data["items"] = [
        {
            column.name: _iso(getattr(item, column.name))
            for column in QuotationLiftItem.__table__.columns
        }
        for item in items
    ]

    return data


def next_quotation_number(db: Session) -> str:
    year = datetime.now().year

    rows = (
        db.query(QuotationMaster)
        .filter(
            QuotationMaster.quotation_no.like(
                f"Q-{year}-%"
            )
        )
        .all()
    )

    highest = 0

    for row in rows:
        try:
            number = int(
                str(row.quotation_no).split("-")[-1]
            )
            highest = max(highest, number)
        except (TypeError, ValueError):
            continue

    return f"Q-{year}-{highest + 1:04d}"


def quotation_amounts(
    items: list[dict[str, Any]],
    discount_amount: float,
    gst_percent: float,
):
    basic_amount = 0.0

    for item in items:
        try:
            quantity = int(item.get("quantity") or 1)
        except (TypeError, ValueError):
            quantity = 1

        try:
            unit_price = float(
                item.get("unit_price") or 0
            )
        except (TypeError, ValueError):
            unit_price = 0.0

        basic_amount += quantity * unit_price

    taxable_amount = max(
        basic_amount - discount_amount,
        0.0,
    )

    gst_amount = (
        taxable_amount * gst_percent / 100.0
    )

    grand_total = taxable_amount + gst_amount

    return (
        basic_amount,
        taxable_amount,
        gst_amount,
        grand_total,
    )



@app.get("/api/v1/quotations/prefill/{lead_id}")
def quotation_prefill(
    lead_id: int,
    db: Session = Depends(get_db),
):
    lead = get_lead_or_404(db, lead_id)

    return {
        "lead_id": lead.id,
        "lead_display_id": lead.lead_id,

        "lead_collection_by":
            lead.lead_collector_name,

        "marketing_by":
            lead.marketing_head,

        "customer_name":
            lead.customer_name,

        "construction_building_name":
            lead.construction_building_name,

        "contact_no":
            lead.mobile,

        "office_address":
            lead.office_address,

        "site_address":
            lead.site_address,

        "location":
            lead.location,

        "lift_type":
            lead.lift_type,

        "quotation_type":
            "TRACTION",
    }


@app.get("/api/v1/quotations")
def list_quotations(
    lead_id: int | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(QuotationMaster).filter(
        QuotationMaster.active.is_(True)
    )

    if lead_id is not None:
        query = query.filter(
            QuotationMaster.lead_id == lead_id
        )

    rows = query.order_by(
        QuotationMaster.id.desc()
    ).all()

    return [
        quotation_to_dict(row, db)
        for row in rows
    ]


@app.get("/api/v1/quotations/{quotation_id}")
def get_quotation(
    quotation_id: int,
    db: Session = Depends(get_db),
):
    row = (
        db.query(QuotationMaster)
        .filter(
            QuotationMaster.id == quotation_id,
            QuotationMaster.active.is_(True),
        )
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Quotation not found",
        )

    return quotation_to_dict(row, db)


@app.post("/api/v1/quotations")
def create_quotation(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
):
    # -----------------------------------------------------
    # LEAD
    # -----------------------------------------------------

    lead_id = payload.get("lead_id")

    if lead_id is None:
        raise HTTPException(
            status_code=400,
            detail="Lead ID is required",
        )

    try:
        lead_id = int(lead_id)
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid Lead ID",
        )

    lead = get_lead_or_404(
        db,
        lead_id,
    )

    # -----------------------------------------------------
    # QUOTATION TYPE
    # -----------------------------------------------------

    quotation_type = str(
        payload.get("quotation_type")
        or "TRACTION"
    ).strip().upper()

    valid_types = {
        row["id"]
        for row in QUOTATION_TYPES
    }

    if quotation_type not in valid_types:
        raise HTTPException(
            status_code=400,
            detail="Invalid quotation type",
        )

    # Only Traction is fully configured at this stage.
    if quotation_type != "TRACTION":
        raise HTTPException(
            status_code=400,
            detail=(
                "This quotation format is not configured yet"
            ),
        )

    # -----------------------------------------------------
    # TECHNICAL DATA
    # -----------------------------------------------------

    technical_data = payload.get(
        "technical_data"
    ) or {}

    if not isinstance(
        technical_data,
        dict,
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid technical data",
        )

    definitions = quotation_fields_for_type(
        quotation_type
    )

    missing_fields = []

    for definition in definitions:
        if not definition.get("required"):
            continue

        key = definition["key"]

        # Commercial fields are validated separately.
        if key in {
            "price_including_gst",
            "license_fee",
            "quotation_validity",
            "cabin_model_no",
            "extra_payment",
        }:
            continue

        value = technical_data.get(key)

        if value is None or not str(value).strip():
            missing_fields.append(
                definition["label"]
            )

    if missing_fields:
        raise HTTPException(
            status_code=400,
            detail=(
                "Required quotation fields missing: "
                + ", ".join(missing_fields)
            ),
        )

    # -----------------------------------------------------
    # COMMERCIAL DATA
    # -----------------------------------------------------

    commercial_data = payload.get(
        "commercial_data"
    ) or {}

    if not isinstance(
        commercial_data,
        dict,
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid commercial data",
        )

    price_value = (
        commercial_data.get(
            "price_including_gst"
        )
        if "price_including_gst"
        in commercial_data
        else payload.get(
            "price_including_gst"
        )
    )

    try:
        price_including_gst = float(
            price_value or 0
        )
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid quotation price",
        )

    if price_including_gst <= 0:
        raise HTTPException(
            status_code=400,
            detail="Price including GST is required",
        )

    license_fee = (
        commercial_data.get("license_fee")
        or payload.get("license_fee")
    )

    quotation_validity = (
        commercial_data.get(
            "quotation_validity"
        )
        or payload.get(
            "quotation_validity"
        )
    )

    if not str(
        license_fee or ""
    ).strip():
        raise HTTPException(
            status_code=400,
            detail="License Fee is required",
        )

    if not str(
        quotation_validity or ""
    ).strip():
        raise HTTPException(
            status_code=400,
            detail="Quotation Validity is required",
        )

    commercial_data[
        "price_including_gst"
    ] = price_including_gst

    commercial_data[
        "license_fee"
    ] = license_fee

    commercial_data[
        "quotation_validity"
    ] = quotation_validity

    commercial_data[
        "cabin_model_no"
    ] = (
        commercial_data.get(
            "cabin_model_no"
        )
        or payload.get(
            "cabin_model_no"
        )
    )

    commercial_data[
        "extra_payment"
    ] = (
        commercial_data.get(
            "extra_payment"
        )
        or payload.get(
            "extra_payment"
        )
    )

    # -----------------------------------------------------
    # GST BREAKDOWN
    #
    # Current Google Form price is already INCLUDING GST.
    # Therefore do NOT add another 18%.
    # -----------------------------------------------------

    try:
        gst_percent = float(
            payload.get("gst_percent")
            or 18
        )
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid GST percentage",
        )

    divisor = 1 + (
        gst_percent / 100
    )

    taxable_amount = (
        price_including_gst / divisor
        if divisor > 0
        else price_including_gst
    )

    gst_amount = (
        price_including_gst
        - taxable_amount
    )

    now = datetime.now()

    # -----------------------------------------------------
    # SAVE HEADER
    # -----------------------------------------------------

    quotation = QuotationMaster(
        quotation_no=next_quotation_number(
            db
        ),
        revision_no=0,

        quotation_type=quotation_type,

        power_type=(
            "1_PHASE"
            if quotation_type ==
                "MRL_1_PHASE"
            else
            "3_PHASE"
            if quotation_type ==
                "MRL_3_PHASE"
            else None
        ),

        template_code=quotation_type,

        technical_data=json.dumps(
            technical_data,
            ensure_ascii=False,
        ),

        commercial_data=json.dumps(
            commercial_data,
            ensure_ascii=False,
        ),

        lead_id=lead.id,

        quotation_date=now,

        valid_until=parse_datetime(
            payload.get("valid_until")
        ),

        status="Draft",

        # Snapshot from Lead.
        customer_name=
            lead.customer_name,

        construction_building_name=
            lead.construction_building_name,

        mobile=lead.mobile,

        office_address=
            lead.office_address,

        site_address=
            lead.site_address,

        location=lead.location,

        # Price entered in current Google Form
        # is already GST inclusive.
        basic_amount=taxable_amount,

        discount_amount=0,

        taxable_amount=taxable_amount,

        gst_percent=gst_percent,

        gst_amount=gst_amount,

        grand_total=
            price_including_gst,

        payment_terms=payload.get(
            "payment_terms"
        ),

        delivery_period=payload.get(
            "delivery_period"
        ),

        installation_terms=payload.get(
            "installation_terms"
        ),

        warranty_terms=payload.get(
            "warranty_terms"
        ),

        free_maintenance=payload.get(
            "free_maintenance"
        ),

        remarks=payload.get(
            "remarks"
        ),

        terms_conditions=payload.get(
            "terms_conditions"
        ),

        created_by=payload.get(
            "created_by"
        ),

        created_at=now,
        updated_at=now,
        active=True,
    )

    db.add(quotation)
    db.flush()

    # -----------------------------------------------------
    # ONE PRIMARY LIFT ITEM
    # -----------------------------------------------------

    item = QuotationLiftItem(
        quotation_id=quotation.id,
        item_no=1,

        lift_name=(
            technical_data.get(
                "lift_type"
            )
            or lead.lift_type
            or "Lift"
        ),

        quantity=1,

        capacity_persons=
            technical_data.get(
                "person_capacity"
            ),

        floors=
            technical_data.get(
                "number_of_floor"
            ),

        stops=
            technical_data.get(
                "no_of_stops"
            ),

        travel_height=
            technical_data.get(
                "total_height"
            ),

        lift_type=
            technical_data.get(
                "lift_type"
            ),

        door_type=
            technical_data.get(
                "landing_door_type"
            ),

        door_opening=
            technical_data.get(
                "entrance_opening"
            ),

        ard=
            technical_data.get(
                "ard_required"
            ),

        cabin_finish=
            technical_data.get(
                "car_enclosure"
            ),

        car_door=
            technical_data.get(
                "car_door_type"
            ),

        landing_door=
            technical_data.get(
                "landing_door_type"
            ),

        technical_data=json.dumps(
            technical_data,
            ensure_ascii=False,
        ),

        unit_price=
            price_including_gst,

        total_price=
            price_including_gst,

        display_order=1,

        created_at=now,
        updated_at=now,
        active=True,
    )

    db.add(item)

    # -----------------------------------------------------
    # UPDATE SALES PIPELINE
    # -----------------------------------------------------

    lead.quotation_given = True
    lead.quotation_date = now

    if (
        not lead.order_finalized
        and not lead.order_lost
    ):
        lead.lead_status = "Quotation"

    lead.updated_at = now

    db.commit()
    db.refresh(quotation)

    return quotation_to_dict(
        quotation,
        db,
    )


@app.put("/api/v1/quotations/{quotation_id}")
def update_quotation(
    quotation_id: int,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
):
    quotation = (
        db.query(QuotationMaster)
        .filter(
            QuotationMaster.id == quotation_id,
            QuotationMaster.active.is_(True),
        )
        .first()
    )

    if quotation is None:
        raise HTTPException(
            status_code=404,
            detail="Quotation not found",
        )

    editable_fields = {
        "valid_until",
        "status",
        "discount_amount",
        "gst_percent",
        "payment_terms",
        "delivery_period",
        "installation_terms",
        "warranty_terms",
        "free_maintenance",
        "remarks",
        "terms_conditions",
    }

    for key in editable_fields:
        if key not in payload:
            continue

        value = payload.get(key)

        if key == "valid_until":
            value = parse_datetime(value)

        if key in {
            "discount_amount",
            "gst_percent",
        }:
            try:
                value = float(value or 0)
            except (TypeError, ValueError):
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid {key}",
                )

        setattr(
            quotation,
            key,
            value,
        )

    items = payload.get("items")

    if items is not None:
        if not isinstance(items, list) or not items:
            raise HTTPException(
                status_code=400,
                detail="At least one lift item is required",
            )

        (
            basic_amount,
            taxable_amount,
            gst_amount,
            grand_total,
        ) = quotation_amounts(
            items,
            float(
                quotation.discount_amount or 0
            ),
            float(
                quotation.gst_percent or 0
            ),
        )

        existing_items = (
            db.query(QuotationLiftItem)
            .filter(
                QuotationLiftItem.quotation_id ==
                    quotation.id
            )
            .all()
        )

        for existing in existing_items:
            existing.active = False

        now = datetime.now()

        for index, item_data in enumerate(
            items,
            start=1,
        ):
            quantity = int(
                item_data.get("quantity") or 1
            )
            unit_price = float(
                item_data.get("unit_price") or 0
            )

            db.add(
                QuotationLiftItem(
                    quotation_id=quotation.id,
                    item_no=index,
                    lift_name=item_data.get(
                        "lift_name"
                    ),
                    quantity=quantity,
                    capacity_persons=item_data.get(
                        "capacity_persons"
                    ),
                    capacity_kg=item_data.get(
                        "capacity_kg"
                    ),
                    floors=item_data.get("floors"),
                    stops=item_data.get("stops"),
                    travel_height=item_data.get(
                        "travel_height"
                    ),
                    lift_type=item_data.get(
                        "lift_type"
                    ),
                    installation_type=item_data.get(
                        "installation_type"
                    ),
                    door_type=item_data.get(
                        "door_type"
                    ),
                    door_opening=item_data.get(
                        "door_opening"
                    ),
                    speed=item_data.get("speed"),
                    machine=item_data.get(
                        "machine"
                    ),
                    controller=item_data.get(
                        "controller"
                    ),
                    ard=item_data.get("ard"),
                    cabin_finish=item_data.get(
                        "cabin_finish"
                    ),
                    car_door=item_data.get(
                        "car_door"
                    ),
                    landing_door=item_data.get(
                        "landing_door"
                    ),
                    cop_lop=item_data.get(
                        "cop_lop"
                    ),
                    flooring=item_data.get(
                        "flooring"
                    ),
                    item_description=item_data.get(
                        "item_description"
                    ),
                    unit_price=unit_price,
                    total_price=quantity * unit_price,
                    display_order=index,
                    created_at=now,
                    updated_at=now,
                    active=True,
                )
            )

        quotation.basic_amount = basic_amount
        quotation.taxable_amount = taxable_amount
        quotation.gst_amount = gst_amount
        quotation.grand_total = grand_total

    else:
        basic = float(
            quotation.basic_amount or 0
        )
        discount = float(
            quotation.discount_amount or 0
        )
        gst_percent = float(
            quotation.gst_percent or 0
        )

        taxable = max(
            basic - discount,
            0,
        )

        quotation.taxable_amount = taxable
        quotation.gst_amount = (
            taxable * gst_percent / 100
        )
        quotation.grand_total = (
            taxable + quotation.gst_amount
        )

    quotation.updated_at = datetime.now()

    db.commit()
    db.refresh(quotation)

    return quotation_to_dict(
        quotation,
        db,
    )


@app.post("/api/v1/quotations/{quotation_id}/revision")
def revise_quotation(
    quotation_id: int,
    db: Session = Depends(get_db),
):
    source = (
        db.query(QuotationMaster)
        .filter(
            QuotationMaster.id == quotation_id,
            QuotationMaster.active.is_(True),
        )
        .first()
    )

    if source is None:
        raise HTTPException(
            status_code=404,
            detail="Quotation not found",
        )

    latest_revision = (
        db.query(QuotationMaster)
        .filter(
            QuotationMaster.quotation_no ==
                source.quotation_no
        )
        .order_by(
            QuotationMaster.revision_no.desc()
        )
        .first()
    )

    revision_no = (
        int(latest_revision.revision_no) + 1
        if latest_revision
        else 1
    )

    now = datetime.now()

    revised = QuotationMaster(
        quotation_no=source.quotation_no,
        revision_no=revision_no,
        lead_id=source.lead_id,
        quotation_date=now,
        valid_until=source.valid_until,
        status="Draft",

        customer_name=source.customer_name,
        construction_building_name=
            source.construction_building_name,
        mobile=source.mobile,
        office_address=source.office_address,
        site_address=source.site_address,
        location=source.location,

        basic_amount=source.basic_amount,
        discount_amount=source.discount_amount,
        taxable_amount=source.taxable_amount,
        gst_percent=source.gst_percent,
        gst_amount=source.gst_amount,
        grand_total=source.grand_total,

        payment_terms=source.payment_terms,
        delivery_period=source.delivery_period,
        installation_terms=
            source.installation_terms,
        warranty_terms=source.warranty_terms,
        free_maintenance=
            source.free_maintenance,
        remarks=source.remarks,
        terms_conditions=
            source.terms_conditions,

        created_by=source.created_by,
        created_at=now,
        updated_at=now,
        active=True,
    )

    db.add(revised)
    db.flush()

    source_items = (
        db.query(QuotationLiftItem)
        .filter(
            QuotationLiftItem.quotation_id ==
                source.id,
            QuotationLiftItem.active.is_(True),
        )
        .order_by(
            QuotationLiftItem.display_order
        )
        .all()
    )

    for item in source_items:
        db.add(
            QuotationLiftItem(
                quotation_id=revised.id,
                item_no=item.item_no,
                lift_name=item.lift_name,
                quantity=item.quantity,
                capacity_persons=
                    item.capacity_persons,
                capacity_kg=item.capacity_kg,
                floors=item.floors,
                stops=item.stops,
                travel_height=
                    item.travel_height,
                lift_type=item.lift_type,
                installation_type=
                    item.installation_type,
                door_type=item.door_type,
                door_opening=
                    item.door_opening,
                speed=item.speed,
                machine=item.machine,
                controller=item.controller,
                ard=item.ard,
                cabin_finish=
                    item.cabin_finish,
                car_door=item.car_door,
                landing_door=
                    item.landing_door,
                cop_lop=item.cop_lop,
                flooring=item.flooring,
                item_description=
                    item.item_description,
                unit_price=item.unit_price,
                total_price=item.total_price,
                display_order=
                    item.display_order,
                created_at=now,
                updated_at=now,
                active=True,
            )
        )

    source.status = "Revised"
    source.updated_at = now

    db.commit()
    db.refresh(revised)

    return quotation_to_dict(
        revised,
        db,
    )


# ---------------------------------------------------------
# LEAD ACTIVITY HISTORY
# ---------------------------------------------------------

@app.get("/api/v1/data/leads/{lead_id}/activities")
def get_lead_activities(lead_id: int, db: Session = Depends(get_db)):
    get_lead_or_404(db, lead_id)
    rows = (
        db.query(LeadActivity)
        .filter(LeadActivity.lead_id == lead_id)
        .order_by(LeadActivity.activity_date.desc(), LeadActivity.id.desc())
        .all()
    )
    return [activity_to_dict(row) for row in rows]


@app.post("/api/v1/data/leads/{lead_id}/activities")
def create_lead_activity(lead_id: int, payload: dict[str, Any], db: Session = Depends(get_db)):
    lead = get_lead_or_404(db, lead_id)
    activity_type = str(payload.get("activity_type", "")).strip()
    activity_by = str(payload.get("activity_by", "")).strip()
    remarks = str(payload.get("remarks", "")).strip()

    if not activity_type:
        raise HTTPException(status_code=400, detail="Activity Type is required")
    if not activity_by:
        raise HTTPException(status_code=400, detail="Activity By is required")
    if not remarks:
        raise HTTPException(status_code=400, detail="Remarks is required")

    now = datetime.now()
    row = LeadActivity(
        lead_id=lead_id,
        activity_date=parse_datetime(payload.get("activity_date")) or now,
        activity_type=activity_type,
        activity_by=activity_by,
        remarks=remarks,
        outcome=payload.get("outcome"),
        next_follow_up_date=parse_datetime(payload.get("next_follow_up_date")),
        created_at=now,
    )
    db.add(row)

    if row.next_follow_up_date is not None:
        lead.follow_up_date = row.next_follow_up_date
    lead.updated_at = now

    db.commit()
    db.refresh(row)
    return activity_to_dict(row)


# ---------------------------------------------------------
# FOLLOW-UP
# ---------------------------------------------------------

@app.get("/api/v1/data/follow-ups")
def get_follow_ups(db: Session = Depends(get_db)):
    leads = (
        db.query(Lead)
        .filter(Lead.follow_up_date.isnot(None))
        .order_by(Lead.follow_up_date.asc())
        .all()
    )
    return [lead_to_dict(lead) for lead in leads]


# ---------------------------------------------------------
# MARKETING REPORT
# ---------------------------------------------------------

@app.get("/api/v1/reports/marketing")
def marketing_report(db: Session = Depends(get_db)):
    leads = db.query(Lead).all()

    return {
        "total_leads": len(leads),
        "call_done": sum(1 for lead in leads if lead.call_done is True),
        "appointment_fixed": sum(1 for lead in leads if lead.appointment_fixed is True),
        "site_visit_done": sum(1 for lead in leads if lead.site_visit_done is True),
        "survey_done": sum(1 for lead in leads if lead.survey_done is True),
        "quotation_given": sum(1 for lead in leads if lead.quotation_given is True),
        "negotiation_done": sum(1 for lead in leads if lead.negotiation_done is True),
        "order_finalized": sum(1 for lead in leads if lead.order_finalized is True),
        "order_value": sum(
            float(lead.order_value or 0)
            for lead in leads
            if lead.order_finalized is True
        ),
    }

# Common Bulk Import API
app.include_router(bulk_import_router)


