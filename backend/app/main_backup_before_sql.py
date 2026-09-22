from datetime import datetime
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(
    title="Dorado CRM API",
    version="1.0.0",
)


# ---------------------------------------------------------
# CORS
# ---------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------
# TEMPORARY DATABASE
# Later this will be replaced by PostgreSQL / Supabase.
# ---------------------------------------------------------

LEADS: list[dict[str, Any]] = []


# ---------------------------------------------------------
# MAIN MENU
# ---------------------------------------------------------

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
# FORM SCHEMA
# ---------------------------------------------------------

FORMS = {
    "lead_entry": {
        "code": "lead_entry",
        "title": "Lead Entry",
        "submitEndpoint": "/api/v1/data/leads",
        "fields": [
            {
                "key": "customer_name",
                "label": "Customer Name",
                "type": "text",
                "required": True,
            },
            {
                "key": "mobile",
                "label": "Mobile Number",
                "type": "phone",
                "required": True,
            },
            {
                "key": "location",
                "label": "Location",
                "type": "text",
                "required": False,
            },
            {
                "key": "lead_source",
                "label": "Lead Source",
                "type": "text",
                "required": False,
            },
            {
                "key": "building_type",
                "label": "Building Type",
                "type": "text",
                "required": False,
            },
            {
                "key": "lift_type",
                "label": "Lift Type",
                "type": "text",
                "required": False,
            },
            {
                "key": "requirement_time",
                "label": "Requirement Time",
                "type": "text",
                "required": False,
            },
            {
                "key": "marketing_head",
                "label": "Assigned Marketing Head",
                "type": "text",
                "required": False,
            },
            {
                "key": "remarks",
                "label": "Remarks",
                "type": "textarea",
                "required": False,
            },
        ],
    }
}


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

def get_next_lead_id() -> int:
    if not LEADS:
        return 1

    return max(
        int(lead.get("id", 0))
        for lead in LEADS
    ) + 1


def find_lead(lead_id: int):
    for lead in LEADS:
        if lead.get("id") == lead_id:
            return lead

    return None


# ---------------------------------------------------------
# HEALTH
# ---------------------------------------------------------

@app.get("/health")
def health():
    return {
        "status": "ok",
        "application": "Dorado CRM API",
    }


# ---------------------------------------------------------
# MENU API
# ---------------------------------------------------------

@app.get("/api/v1/menus")
def get_menus():
    return MENUS


# ---------------------------------------------------------
# FORM API
# ---------------------------------------------------------

@app.get("/api/v1/forms/{code}")
def get_form(code: str):

    form = FORMS.get(code)

    if form is None:
        raise HTTPException(
            status_code=404,
            detail="Form not found",
        )

    return form


# ---------------------------------------------------------
# LEAD - GET ALL
# ---------------------------------------------------------

@app.get("/api/v1/data/leads")
def get_leads():

    # Newest lead first
    return sorted(
        LEADS,
        key=lambda item: item.get("id", 0),
        reverse=True,
    )


# ---------------------------------------------------------
# LEAD - CREATE
# ---------------------------------------------------------

@app.post("/api/v1/data/leads")
def create_lead(payload: dict[str, Any]):

    now = datetime.now().isoformat()

    lead_id = get_next_lead_id()

    lead = {
        "id": lead_id,

        # Basic Lead Information
        "customer_name": payload.get(
            "customer_name",
            "",
        ),
        "mobile": payload.get(
            "mobile",
            "",
        ),
        "location": payload.get(
            "location",
            "",
        ),
        "lead_source": payload.get(
            "lead_source",
            "",
        ),
        "building_type": payload.get(
            "building_type",
            "",
        ),
        "lift_type": payload.get(
            "lift_type",
            "",
        ),
        "requirement_time": payload.get(
            "requirement_time",
            "",
        ),

        # Assignment
        "marketing_head": payload.get(
            "marketing_head",
            "",
        ),

        # Sales Pipeline
        "lead_status": payload.get(
            "lead_status",
            "New Lead",
        ),

        "call_done": payload.get(
            "call_done",
            False,
        ),

        "appointment_fixed": payload.get(
            "appointment_fixed",
            False,
        ),

        "site_visit_done": payload.get(
            "site_visit_done",
            False,
        ),

        "survey_done": payload.get(
            "survey_done",
            False,
        ),

        "quotation_given": payload.get(
            "quotation_given",
            False,
        ),

        "negotiation_done": payload.get(
            "negotiation_done",
            False,
        ),

        "order_finalized": payload.get(
            "order_finalized",
            False,
        ),

        # Follow-up
        "follow_up_date": payload.get(
            "follow_up_date",
            None,
        ),

        "revisit_date": payload.get(
            "revisit_date",
            None,
        ),

        "over_phone": payload.get(
            "over_phone",
            False,
        ),

        # Remarks
        "remarks": payload.get(
            "remarks",
            "",
        ),

        # Dates
        "lead_date": payload.get(
            "lead_date",
            now,
        ),

        "created_at": now,
        "updated_at": now,
    }

    LEADS.append(lead)

    return lead


# ---------------------------------------------------------
# LEAD - GET ONE
# ---------------------------------------------------------

@app.get("/api/v1/data/leads/{lead_id}")
def get_lead(lead_id: int):

    lead = find_lead(lead_id)

    if lead is None:
        raise HTTPException(
            status_code=404,
            detail="Lead not found",
        )

    return lead


# ---------------------------------------------------------
# LEAD - UPDATE
# ---------------------------------------------------------

@app.put("/api/v1/data/leads/{lead_id}")
def update_lead(
    lead_id: int,
    payload: dict[str, Any],
):

    lead = find_lead(lead_id)

    if lead is None:
        raise HTTPException(
            status_code=404,
            detail="Lead not found",
        )

    protected_fields = {
        "id",
        "created_at",
    }

    for key, value in payload.items():

        if key not in protected_fields:
            lead[key] = value

    lead["updated_at"] = (
        datetime.now().isoformat()
    )

    return lead


# ---------------------------------------------------------
# LEAD - DELETE
# ---------------------------------------------------------

@app.delete("/api/v1/data/leads/{lead_id}")
def delete_lead(lead_id: int):

    lead = find_lead(lead_id)

    if lead is None:
        raise HTTPException(
            status_code=404,
            detail="Lead not found",
        )

    LEADS.remove(lead)

    return {
        "success": True,
        "message": "Lead deleted successfully",
    }


# ---------------------------------------------------------
# FOLLOW-UP
# ---------------------------------------------------------

@app.get("/api/v1/data/follow-ups")
def get_follow_ups():

    return [
        lead
        for lead in LEADS
        if lead.get("follow_up_date")
    ]


# ---------------------------------------------------------
# MARKETING REPORT
# ---------------------------------------------------------

@app.get("/api/v1/reports/marketing")
def marketing_report():

    return {
        "total_leads": len(LEADS),

        "call_done": sum(
            1
            for lead in LEADS
            if lead.get("call_done") is True
        ),

        "appointment_fixed": sum(
            1
            for lead in LEADS
            if lead.get("appointment_fixed") is True
        ),

        "site_visit_done": sum(
            1
            for lead in LEADS
            if lead.get("site_visit_done") is True
        ),

        "survey_done": sum(
            1
            for lead in LEADS
            if lead.get("survey_done") is True
        ),

        "quotation_given": sum(
            1
            for lead in LEADS
            if lead.get("quotation_given") is True
        ),

        "negotiation_done": sum(
            1
            for lead in LEADS
            if lead.get("negotiation_done") is True
        ),

        "order_finalized": sum(
            1
            for lead in LEADS
            if lead.get("order_finalized") is True
        ),
    }