from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    Integer,
    String,
    Text,
    UniqueConstraint,
    ForeignKey,
)

from .database import Base


# =========================================================
# LEADS
# =========================================================

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

    construction_building_name = Column(String(255), nullable=True)
    office_address = Column(Text, nullable=True)
    site_address = Column(Text, nullable=True)
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



# =========================================================
# SALES QUOTATION
# =========================================================

class QuotationMaster(Base):
    __tablename__ = "quotation_master"

    id = Column(Integer, primary_key=True, autoincrement=True)

    quotation_no = Column(String(50), nullable=False, index=True)
    revision_no = Column(Integer, default=0, nullable=False)

    # =====================================================
    # QUOTATION FORMAT
    # =====================================================
    # TRACTION
    # GOODS
    # HYDRAULIC
    # MRL
    # MRL_STRUCTURE

    quotation_type = Column(
        String(50),
        default="TRACTION",
        nullable=False,
        index=True,
    )

    # Used mainly for MRL quotations:
    # 1_PHASE / 3_PHASE
    power_type = Column(String(30), nullable=True)

    # Template/version used to generate the quotation.
    template_code = Column(String(100), nullable=True)

    # Full technical snapshot in JSON text.
    # Keeps historical quotations unchanged even if
    # Data Master values are modified later.
    technical_data = Column(Text, nullable=True)

    # Optional commercial/custom data snapshot.
    commercial_data = Column(Text, nullable=True)

    # Link with CRM Lead.
    lead_id = Column(Integer, ForeignKey("leads.id"), nullable=False, index=True)

    quotation_date = Column(DateTime, default=datetime.now, nullable=False)
    valid_until = Column(DateTime, nullable=True)

    status = Column(String(30), default="Draft", nullable=False)

    # Snapshot of customer details at quotation time.
    customer_name = Column(String(200), nullable=False)
    construction_building_name = Column(String(255), nullable=True)
    mobile = Column(String(30), nullable=True)
    office_address = Column(Text, nullable=True)
    site_address = Column(Text, nullable=True)
    location = Column(String(250), nullable=True)

    # Commercial summary.
    basic_amount = Column(Float, default=0)
    discount_amount = Column(Float, default=0)
    taxable_amount = Column(Float, default=0)

    gst_percent = Column(Float, default=18)
    gst_amount = Column(Float, default=0)
    grand_total = Column(Float, default=0)

    payment_terms = Column(Text, nullable=True)
    delivery_period = Column(String(250), nullable=True)
    installation_terms = Column(Text, nullable=True)
    warranty_terms = Column(Text, nullable=True)
    free_maintenance = Column(String(250), nullable=True)

    remarks = Column(Text, nullable=True)
    terms_conditions = Column(Text, nullable=True)

    created_by = Column(String(30), nullable=True)
    created_at = Column(DateTime, default=datetime.now, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )

    active = Column(Boolean, default=True, nullable=False)

    __table_args__ = (
        UniqueConstraint(
            "quotation_no",
            "revision_no",
            name="uq_quotation_revision",
        ),
    )


class QuotationLiftItem(Base):
    __tablename__ = "quotation_lift_items"

    id = Column(Integer, primary_key=True, autoincrement=True)

    quotation_id = Column(
        Integer,
        ForeignKey("quotation_master.id"),
        nullable=False,
        index=True,
    )

    item_no = Column(Integer, default=1, nullable=False)

    lift_name = Column(String(150), nullable=True)
    quantity = Column(Integer, default=1, nullable=False)

    capacity_persons = Column(Integer, nullable=True)
    capacity_kg = Column(Float, nullable=True)

    floors = Column(String(100), nullable=True)
    stops = Column(Integer, nullable=True)
    travel_height = Column(Float, nullable=True)

    lift_type = Column(String(150), nullable=True)
    installation_type = Column(String(150), nullable=True)

    door_type = Column(String(150), nullable=True)
    door_opening = Column(String(100), nullable=True)

    speed = Column(String(100), nullable=True)
    machine = Column(String(200), nullable=True)
    controller = Column(String(200), nullable=True)
    ard = Column(String(100), nullable=True)

    cabin_finish = Column(String(200), nullable=True)
    car_door = Column(String(200), nullable=True)
    landing_door = Column(String(200), nullable=True)

    cop_lop = Column(String(250), nullable=True)
    flooring = Column(String(200), nullable=True)

    item_description = Column(Text, nullable=True)

    # Type-specific technical specification snapshot.
    #
    # Example:
    # TRACTION -> machine room / rope / motor
    # GOODS -> goods cabin / collapsible gate / load
    # HYDRAULIC -> power pack / cylinder
    # MRL -> gearless machine / phase
    # MRL_STRUCTURE -> structure + civil + covering
    technical_data = Column(Text, nullable=True)

    # Structure / Civil / Covering details where applicable.
    structure_data = Column(Text, nullable=True)
    civil_data = Column(Text, nullable=True)
    covering_data = Column(Text, nullable=True)

    unit_price = Column(Float, default=0)
    total_price = Column(Float, default=0)

    display_order = Column(Integer, default=0)

    created_at = Column(DateTime, default=datetime.now, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )

    active = Column(Boolean, default=True, nullable=False)


# =========================================================
# EMPLOYEE / USER MASTER
# Existing table kept compatible
# =========================================================

class EmployeeMaster(Base):
    __tablename__ = "employee_master"

    # =====================================================
    # BASIC INFORMATION
    # =====================================================

    id = Column(String(30), primary_key=True)
    employee_name = Column(String(150), nullable=False)

    father_name = Column(String(150), nullable=True)
    date_of_birth = Column(DateTime, nullable=True)
    gender = Column(String(30), nullable=True)

    mobile = Column(String(30), nullable=True)
    alternate_mobile = Column(String(30), nullable=True)
    email = Column(String(150), nullable=True)

    # =====================================================
    # ADDRESS
    # =====================================================

    present_address = Column(Text, nullable=True)
    permanent_address = Column(Text, nullable=True)

    # =====================================================
    # EMPLOYMENT INFORMATION
    # =====================================================

    designation = Column(String(100), nullable=True)
    date_of_joining = Column(DateTime, nullable=True)

        # =====================================================
    # ADDITIONAL EMPLOYMENT INFORMATION
    # =====================================================

    employee_type = Column(String(50), nullable=True)
    work_location = Column(String(150), nullable=True)
    date_of_exit = Column(DateTime, nullable=True)

    # =====================================================
    # PF / ESIC APPLICABILITY
    # =====================================================

    pf_applicable = Column(Boolean, default=False, nullable=False)
    esic_applicable = Column(Boolean, default=False, nullable=False)

    # =====================================================
    # SALARY INFORMATION
    # =====================================================

    basic_salary = Column(Float, nullable=True)
    gross_salary = Column(Float, nullable=True)
    ctc = Column(Float, nullable=True)

    hra = Column(Float, nullable=True)
    conveyance_allowance = Column(Float, nullable=True)
    other_allowance = Column(Float, nullable=True)

    employee_pf_contribution = Column(Float, nullable=True)
    employer_pf_contribution = Column(Float, nullable=True)

    employee_esic_contribution = Column(Float, nullable=True)
    employer_esic_contribution = Column(Float, nullable=True)

    # =====================================================
    # EMERGENCY / PERSONAL
    # =====================================================

    blood_group = Column(String(20), nullable=True)
    emergency_contact_name = Column(String(150), nullable=True)
    emergency_contact_mobile = Column(String(30), nullable=True)
    emergency_contact_relation = Column(String(50), nullable=True)

    active = Column(Boolean, default=True, nullable=False)

    # Legacy display-text fields retained for compatibility
    department = Column(String(100), nullable=True)
    reporting_manager = Column(String(150), nullable=True)
    app_role = Column(String(100), nullable=True)

    # Stable master references
    department_id = Column(String(30), nullable=True, index=True)
    role_id = Column(String(30), nullable=True, index=True)
    reporting_manager_id = Column(String(30), nullable=True, index=True)

    # =====================================================
    # GOVERNMENT / IDENTITY DETAILS
    # =====================================================

    aadhaar_number = Column(String(20), nullable=True)
    pan_number = Column(String(20), nullable=True)

    # =====================================================
    # PF / ESIC
    # =====================================================

    uan_number = Column(String(30), nullable=True)
    pf_number = Column(String(50), nullable=True)
    esic_number = Column(String(50), nullable=True)

    # =====================================================
    # BANK DETAILS
    # =====================================================

    bank_name = Column(String(150), nullable=True)
    bank_account_holder_name = Column(String(150), nullable=True)
    bank_account_number = Column(String(50), nullable=True)
    bank_ifsc = Column(String(20), nullable=True)
    bank_branch = Column(String(150), nullable=True)

    # =====================================================
    # PASSWORD / LOGIN SECURITY
    # =====================================================

    password = Column(String(255), nullable=True)
    force_password_reset = Column(Boolean, default=False)

    # Pet name will NOT be stored as readable text.
    # Only its password-style hash will be stored.
    security_pet_name_hash = Column(String(255), nullable=True)

# =========================================================
# EMPLOYEE DOCUMENTS
# =========================================================

class EmployeeDocument(Base):
    __tablename__ = "employee_documents"

    id = Column(Integer, primary_key=True, autoincrement=True)

    employee_id = Column(
        String(30),
        ForeignKey("employee_master.id"),
        nullable=False,
        index=True,
    )

    document_type = Column(String(100), nullable=False)
    document_name = Column(String(200), nullable=True)

    document_number = Column(String(100), nullable=True)

    file_url = Column(Text, nullable=True)

    issue_date = Column(DateTime, nullable=True)
    expiry_date = Column(DateTime, nullable=True)

    remarks = Column(Text, nullable=True)

    active = Column(Boolean, default=True, nullable=False)

    uploaded_by = Column(String(30), nullable=True)

    uploaded_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

# =========================================================
# ROLE MASTER
# Existing table kept compatible
# =========================================================

class RoleMaster(Base):
    __tablename__ = "role_master"

    id = Column(String(30), primary_key=True)
    role_name = Column(String(100), nullable=False)
    role_level = Column(Integer)
    active = Column(Boolean, default=True, nullable=False)


# =========================================================
# DEPARTMENT MASTER
# Existing table kept compatible
# =========================================================

class DepartmentMaster(Base):
    __tablename__ = "department_master"

    id = Column(String(30), primary_key=True)
    department_name = Column(String(100), nullable=False)
    active = Column(Boolean, default=True, nullable=False)


# =========================================================
# MODULE MASTER
#
# Controls dynamic menu structure.
# parent_id = None -> main menu
# parent_id = another module code -> submenu
# =========================================================

class ModuleMaster(Base):
    __tablename__ = "module_master"

    id = Column(String(50), primary_key=True)

    module_name = Column(String(150), nullable=False)
    subtitle = Column(String(250), nullable=True)

    department_id = Column(String(30), nullable=True, index=True)

    parent_id = Column(String(50), nullable=True, index=True)

    icon = Column(String(100), nullable=True)

    route_type = Column(
        String(50),
        default="page",
        nullable=False,
    )

    route_name = Column(String(150), nullable=True)
    form_code = Column(String(100), nullable=True)

    display_order = Column(Integer, default=0)

    active = Column(Boolean, default=True, nullable=False)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )


# =========================================================
# ROLE PERMISSION
#
# Default permissions for a Role + Module
# =========================================================

class RolePermission(Base):
    __tablename__ = "role_permissions"

    id = Column(Integer, primary_key=True, autoincrement=True)

    role_id = Column(
        String(30),
        nullable=False,
        index=True,
    )

    module_id = Column(
        String(50),
        nullable=False,
        index=True,
    )

    can_view = Column(Boolean, default=False, nullable=False)
    can_add = Column(Boolean, default=False, nullable=False)
    can_edit = Column(Boolean, default=False, nullable=False)
    can_delete = Column(Boolean, default=False, nullable=False)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint(
            "role_id",
            "module_id",
            name="uq_role_module_permission",
        ),
    )


# =========================================================
# USER PERMISSION OVERRIDE
#
# Optional.
# If no record exists, RolePermission is used.
#
# Example:
# Executive role -> Delete OFF
# Specific user -> Delete ON
# =========================================================

class UserPermission(Base):
    __tablename__ = "user_permissions"

    id = Column(Integer, primary_key=True, autoincrement=True)

    user_id = Column(
        String(30),
        nullable=False,
        index=True,
    )

    module_id = Column(
        String(50),
        nullable=False,
        index=True,
    )

    can_view = Column(Boolean, nullable=True)
    can_add = Column(Boolean, nullable=True)
    can_edit = Column(Boolean, nullable=True)
    can_delete = Column(Boolean, nullable=True)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "module_id",
            name="uq_user_module_permission",
        ),
    )


# =========================================================
# MASTER TYPE
#
# Defines what kind of master data exists.
#
# Examples:
# LEAD_SOURCE
# BUILDING_TYPE
# LIFT_TYPE
# LEAD_PRIORITY
# BREAKDOWN_TYPE
# MATERIAL_CATEGORY
# =========================================================

class MasterType(Base):
    __tablename__ = "master_types"

    id = Column(String(50), primary_key=True)

    master_name = Column(String(150), nullable=False)

    department_id = Column(
        String(30),
        nullable=True,
        index=True,
    )

    description = Column(Text, nullable=True)

    allow_global = Column(
        Boolean,
        default=False,
        nullable=False,
    )

    display_order = Column(Integer, default=0)

    active = Column(Boolean, default=True, nullable=False)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )


# =========================================================
# DYNAMIC MASTER DATA
#
# Used for single add / bulk add.
#
# department_id can contain:
# DEP001 / DEP002 / GLOBAL etc.
# =========================================================

class MasterData(Base):
    __tablename__ = "master_data"

    id = Column(Integer, primary_key=True, autoincrement=True)

    master_type_id = Column(
        String(50),
        nullable=False,
        index=True,
    )

    department_id = Column(
        String(30),
        nullable=True,
        index=True,
    )

    code = Column(
        String(50),
        nullable=False,
        index=True,
    )

    name = Column(
        String(250),
        nullable=False,
    )

    description = Column(Text, nullable=True)

    extra_data = Column(Text, nullable=True)

    display_order = Column(Integer, default=0)

    active = Column(Boolean, default=True, nullable=False)

    created_by = Column(String(30), nullable=True)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

    updated_by = Column(String(30), nullable=True)

    updated_at = Column(
        DateTime,
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint(
            "master_type_id",
            "department_id",
            "code",
            name="uq_master_data_code",
        ),
    )


# =========================================================
# LOGIN SESSION / TOKEN CONTROL
#
# Useful for logout, device/session tracking and revocation.
# =========================================================

class UserSession(Base):
    __tablename__ = "user_sessions"

    id = Column(String(100), primary_key=True)

    user_id = Column(
        String(30),
        nullable=False,
        index=True,
    )

    token_jti = Column(
        String(100),
        unique=True,
        nullable=False,
        index=True,
    )

    device_name = Column(String(200), nullable=True)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )

    expires_at = Column(DateTime, nullable=False)

    revoked = Column(
        Boolean,
        default=False,
        nullable=False,
    )


# =========================================================
# AUDIT LOG
#
# Records important Add/Edit/Delete/Admin actions.
# =========================================================

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)

    user_id = Column(String(30), nullable=True, index=True)

    module_id = Column(String(50), nullable=True, index=True)

    action = Column(String(50), nullable=False)

    record_type = Column(String(100), nullable=True)
    record_id = Column(String(100), nullable=True)

    details = Column(Text, nullable=True)

    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )


# =========================================================
# EXISTING SALES MASTER TABLES
# Kept for current Lead API compatibility
# =========================================================

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
    # =========================================================
# PASSWORD RESET OTP
# =========================================================

class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otps"

    id = Column(String(36), primary_key=True)

    user_id = Column(
        String(30),
        ForeignKey("employee_master.id"),
        nullable=False,
        index=True,
    )

    otp_hash = Column(String(255), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False, nullable=False)
    created_at = Column(
        DateTime,
        default=datetime.now,
        nullable=False,
    )