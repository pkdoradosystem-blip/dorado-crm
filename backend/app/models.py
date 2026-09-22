from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String, Text
from .database import Base


class Lead(Base):
    __tablename__ = "leads"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    timestamp = Column(DateTime, nullable=False)
    lead_date = Column(DateTime, nullable=False)
    lead_key = Column(String(100), unique=True, index=True, nullable=False)
    lead_id = Column(String(20), unique=True, index=True, nullable=False)

    lead_collector_name = Column(String(150), nullable=True)
    collector_view = Column(String(100), nullable=True)
    collector_remarks = Column(Text, nullable=True)
    lead_source = Column(String(150), nullable=True)
    customer_name = Column(String(200), nullable=False)
    mobile = Column(String(30), nullable=False)
    location = Column(String(250), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    building_type = Column(String(150), nullable=True)
    lift_type = Column(String(150), nullable=True)
    requirement_time = Column(String(100), nullable=True)

    call_done = Column(Boolean, default=False, nullable=False)
    appointment_fixed = Column(Boolean, default=False, nullable=False)
    appointment_date = Column(DateTime, nullable=True)
    site_visit_done = Column(Boolean, default=False, nullable=False)
    site_visit_date = Column(DateTime, nullable=True)
    survey_done = Column(Boolean, default=False, nullable=False)
    survey_date = Column(DateTime, nullable=True)
    quotation_given = Column(Boolean, default=False, nullable=False)
    quotation_date = Column(DateTime, nullable=True)

    negotiation_status = Column(String(100), nullable=True)
    negotiation_date = Column(DateTime, nullable=True)
    negotiation_done = Column(Boolean, default=False, nullable=False)

    order_finalized = Column(Boolean, default=False, nullable=False)
    order_date = Column(DateTime, nullable=True)
    order_value = Column(Float, nullable=True)
    order_lost = Column(Boolean, default=False, nullable=False)
    lost_date = Column(DateTime, nullable=True)

    lead_status = Column(String(100), default="New Lead", nullable=False)
    remarks = Column(Text, nullable=True)
    new_remarks = Column(Text, nullable=True)
    last_call = Column(DateTime, nullable=True)
    follow_up_date = Column(DateTime, nullable=True)
    revisit_date = Column(DateTime, nullable=True)
    over_phone = Column(Boolean, default=False, nullable=False)
    score = Column(Float, nullable=True)
    duplicate_check = Column(String(100), nullable=True)

    image_1 = Column(Text, nullable=True)
    image_2 = Column(Text, nullable=True)
    image_3 = Column(Text, nullable=True)

    marketing_head = Column(String(150), nullable=True)
    lead_priority = Column(String(50), nullable=True)
    expected_order_value = Column(Float, nullable=True)
    expected_close_date = Column(DateTime, nullable=True)
    lost_reason = Column(Text, nullable=True)
    created_by = Column(String(150), nullable=True)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)
    active = Column(Boolean, default=True, nullable=False)


class LeadActivity(Base):
    __tablename__ = "lead_activities"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    lead_id = Column(Integer, nullable=False, index=True)

    activity_date = Column(DateTime, nullable=False)
    activity_type = Column(String(100), nullable=False)
    activity_by = Column(String(150), nullable=False)

    remarks = Column(Text, nullable=False)
    outcome = Column(String(150), nullable=True)
    next_follow_up_date = Column(DateTime, nullable=True)

    created_at = Column(DateTime, nullable=False)


class EmployeeMaster(Base):
    __tablename__ = "employee_master"
    id = Column(String(30), primary_key=True)
    employee_name = Column(String(150), nullable=False)
    email = Column(String(150))
    designation = Column(String(100))
    mobile = Column(String(30))
    active = Column(Boolean, default=True, nullable=False)
    app_role = Column(String(100))
    password = Column(String(255))
    force_password_reset = Column(Boolean, default=False)
    department = Column(String(100))
    reporting_manager = Column(String(150))
    date_of_joining = Column(DateTime)


class RoleMaster(Base):
    __tablename__ = "role_master"
    id = Column(String(30), primary_key=True)
    role_name = Column(String(100), nullable=False)
    role_level = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class DepartmentMaster(Base):
    __tablename__ = "department_master"
    id = Column(String(30), primary_key=True)
    department_name = Column(String(100), nullable=False)
    active = Column(Boolean, default=True, nullable=False)


class LeadSourceMaster(Base):
    __tablename__ = "lead_source_master"
    id = Column(String(30), primary_key=True)
    lead_source = Column(String(150), nullable=False)
    active = Column(Boolean, default=True, nullable=False)


class LiftTypeMaster(Base):
    __tablename__ = "lift_type_master"
    id = Column(String(30), primary_key=True)
    lift_type = Column(String(150), nullable=False)
    active = Column(Boolean, default=True, nullable=False)


class BuildingTypeMaster(Base):
    __tablename__ = "building_type_master"
    id = Column(String(30), primary_key=True)
    building_type = Column(String(150), nullable=False)
    active = Column(Boolean, default=True, nullable=False)


class RequirementTimeMaster(Base):
    __tablename__ = "requirement_time_master"
    id = Column(String(30), primary_key=True)
    requirement_time = Column(String(100), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class LeadStatusMaster(Base):
    __tablename__ = "lead_status_master"
    id = Column(String(30), primary_key=True)
    lead_status = Column(String(100), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class LeadPriorityMaster(Base):
    __tablename__ = "lead_priority_master"
    id = Column(String(30), primary_key=True)
    lead_priority = Column(String(50), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class NegotiationStatusMaster(Base):
    __tablename__ = "negotiation_status_master"
    id = Column(String(30), primary_key=True)
    negotiation_status = Column(String(100), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class OrderStatusMaster(Base):
    __tablename__ = "order_status_master"
    id = Column(String(30), primary_key=True)
    order_status = Column(String(100), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class LostReasonMaster(Base):
    __tablename__ = "lost_reason_master"
    id = Column(String(30), primary_key=True)
    loss_category = Column(String(150))
    lost_reason = Column(String(250), nullable=False)
    root_cause_type = Column(String(100))
    controllable = Column(String(20))
    severity = Column(String(50))
    management_action_required = Column(String(20))
    recommended_action = Column(Text)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class LostStageMaster(Base):
    __tablename__ = "lost_stage_master"
    id = Column(String(30), primary_key=True)
    lost_stage = Column(String(100), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class DecisionInfluenceMaster(Base):
    __tablename__ = "decision_influence_master"
    id = Column(String(30), primary_key=True)
    decision_influence = Column(String(150), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class CompetitorMaster(Base):
    __tablename__ = "competitor_master"
    id = Column(String(30), primary_key=True)
    competitor_name = Column(String(200))
    company_type = Column(String(100))
    primary_area = Column(String(150))
    price_position = Column(String(100))
    product_quality = Column(String(100))
    service_strength = Column(String(100))
    market_relationship = Column(String(100))
    payment_flexibility = Column(String(100))
    warranty_position = Column(String(100))
    installation_capability = Column(String(100))
    main_strength = Column(Text)
    main_weakness = Column(Text)
    typical_price_difference = Column(String(100))
    remarks = Column(Text)
    last_updated = Column(DateTime)
    active = Column(Boolean, default=True, nullable=False)


class WinReasonMaster(Base):
    __tablename__ = "win_reason_master"
    id = Column(String(30), primary_key=True)
    win_category = Column(String(150))
    win_reason = Column(String(250), nullable=False)
    strength_type = Column(String(100))
    repeatable = Column(String(20))
    business_importance = Column(String(50))
    recommended_strategy = Column(Text)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class InterventionTypeMaster(Base):
    __tablename__ = "intervention_type_master"
    id = Column(String(30), primary_key=True)
    intervention_type = Column(String(200), nullable=False)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class SalesRiskReasonMaster(Base):
    __tablename__ = "sales_risk_reason_master"
    id = Column(String(30), primary_key=True)
    risk_category = Column(String(150))
    risk_reason = Column(String(250), nullable=False)
    risk_weight = Column(Integer)
    management_attention = Column(String(20))
    default_action = Column(Text)
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class CustomerObjectionMaster(Base):
    __tablename__ = "customer_objection_master"
    id = Column(String(30), primary_key=True)
    objection_category = Column(String(150))
    customer_objection = Column(String(250), nullable=False)
    likely_underlying_concern = Column(Text)
    suggested_response_strategy = Column(Text)
    escalation_required = Column(String(20))
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class SalesActionMaster(Base):
    __tablename__ = "sales_action_master"
    id = Column(String(30), primary_key=True)
    action_category = Column(String(150))
    sales_action = Column(String(250), nullable=False)
    applicable_stage = Column(String(100))
    priority = Column(String(50))
    sla_days = Column(Integer)
    management_approval_required = Column(String(20))
    completion_proof_required = Column(String(20))
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


class SalesFollowupOutcomeMaster(Base):
    __tablename__ = "sales_followup_outcome_master"
    id = Column(String(30), primary_key=True)
    outcome_category = Column(String(100))
    followup_outcome = Column(String(250), nullable=False)
    lead_progress = Column(String(100))
    next_action_required = Column(String(20))
    default_next_followup_days = Column(Integer)
    escalation_required = Column(String(20))
    sort_order = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)