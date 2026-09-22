from datetime import datetime
from typing import Any
import uuid

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from .database import Base, engine, get_db, SessionLocal
from .admin_api import router as admin_router, sync_foundation_data
from .models import (
    Lead,
    LeadActivity,
    EmployeeMaster,
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
             "options": [x["value"] for x in employee_options(db, "lead collector")]},
            {"key": "lead_source", "label": "Lead Source", "type": "dropdown", "required": False,
             "options": [x["value"] for x in active_master_values(db, LeadSourceMaster, "lead_source")]},
            {"key": "customer_name", "label": "Customer Name", "type": "text", "required": True},
            {"key": "mobile", "label": "Mobile", "type": "phone", "required": True},
            {"key": "location", "label": "Location", "type": "map", "required": False},
            {"key": "building_type", "label": "Building Type", "type": "dropdown", "required": False,
             "options": [x["value"] for x in active_master_values(db, BuildingTypeMaster, "building_type")]},
            {"key": "lift_type", "label": "Lift Type", "type": "dropdown", "required": False,
             "options": [x["value"] for x in active_master_values(db, LiftTypeMaster, "lift_type")]},
            {"key": "collector_view", "label": "Executive View", "type": "dropdown", "required": False,
             "options": [
                 "Negative",
                 "Positive",
                 "Customer has Fixed Company",
                 "Customer Not Interested",
                 "No Person Present",
                 "Contact for Next Project",
             ]},
            {"key": "collector_remarks", "label": "Executive Remarks", "type": "dropdown", "required": False,
             "options": [
                 "Take Some Time",
                 "May be Possible",
                 "Visit with Senior",
                 "Site Stop Now",
                 "Site Stop but Open Nearly",
                 "Order Given to Others",
                 "Please Call Next Week",
             ]},
            {"key": "follow_up_date", "label": "Follow-up Date", "type": "date", "required": False},
            {"key": "image_1", "label": "Image 1", "type": "image", "required": False},
            {"key": "image_2", "label": "Image 2", "type": "image", "required": False},
            {"key": "image_3", "label": "Image 3", "type": "image", "required": False},
            {"key": "marketing_head", "label": "Assigned Marketing Head", "type": "auto", "required": False, "readOnly": True},
            {"key": "lead_priority", "label": "Lead Priority", "type": "dropdown", "required": False,
             "options": [x["value"] for x in active_master_values(db, LeadPriorityMaster, "lead_priority")]},
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
        mobile=mobile,
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
