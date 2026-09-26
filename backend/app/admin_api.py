from datetime import datetime, timedelta, timezone
from typing import Any
import os
import uuid

from pydantic import BaseModel

import jwt
from fastapi import APIRouter, Depends, HTTPException, Header
from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from .database import get_db
from .models import (
    EmployeeMaster,
    DepartmentMaster,
    RoleMaster,
    ModuleMaster,
    RolePermission,
    UserPermission,
    MasterType,
    MasterData,
    UserSession,
    AuditLog,
    Lead,
    
)


router = APIRouter(prefix="/api/v1", tags=["Dorado CRM Admin"])

# =========================================================
# SECURITY CONFIG
# =========================================================

SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "DORADO-CRM-CHANGE-THIS-SECRET-IN-PRODUCTION",
)

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 12

password_hash = PasswordHash.recommended()


# =========================================================
# BASIC HELPERS
# =========================================================

def now_local():
    return datetime.now()


def model_to_dict(obj):
    return {
        column.name: (
            getattr(obj, column.name).isoformat()
            if isinstance(getattr(obj, column.name), datetime)
            else getattr(obj, column.name)
        )
        for column in obj.__table__.columns
    }


def audit(
    db: Session,
    user_id: str | None,
    action: str,
    module_id: str | None = None,
    record_type: str | None = None,
    record_id: str | None = None,
    details: str | None = None,
):
    row = AuditLog(
        user_id=user_id,
        module_id=module_id,
        action=action,
        record_type=record_type,
        record_id=record_id,
        details=details,
        created_at=now_local(),
    )
    db.add(row)


def create_password_hash(password: str) -> str:
    return password_hash.hash(password)
def verify_password(password: str, hashed_password: str | None) -> bool:
    if not hashed_password:
        return False

    try:
        return password_hash.verify(password, hashed_password)
    except Exception:
        # Temporary backward compatibility for old plain-text passwords.
        return password == hashed_password

# =========================================================
# PASSWORD RESET HELPERS
# =========================================================



def create_access_token(
    user_id: str,
    session_id: str,
    token_jti: str,
):
    expires = datetime.now(timezone.utc) + timedelta(
        hours=ACCESS_TOKEN_EXPIRE_HOURS
    )

    payload = {
        "sub": user_id,
        "session_id": session_id,
        "jti": token_jti,
        "exp": expires,
    }

    token = jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )

    return token, expires


# =========================================================
# MASTER REFERENCE HELPERS
# =========================================================

def resolve_department(db: Session, value: str | None):
    if not value:
        return None
    text = str(value).strip()
    return (
        db.query(DepartmentMaster)
        .filter((DepartmentMaster.id == text) | (DepartmentMaster.department_name == text))
        .first()
    )


def resolve_role(db: Session, value: str | None):
    if not value:
        return None
    text = str(value).strip()
    return (
        db.query(RoleMaster)
        .filter((RoleMaster.id == text) | (RoleMaster.role_name == text))
        .first()
    )


def apply_user_master_refs(db: Session, row: EmployeeMaster, payload: dict[str, Any]):
    department_value = payload.get("department_id", payload.get("department"))
    if department_value is not None:
        department = resolve_department(db, department_value)
        if department_value and department is None:
            raise HTTPException(status_code=400, detail="Invalid Department")
        row.department_id = department.id if department else None
        row.department = department.department_name if department else None

    role_value = payload.get("role_id", payload.get("app_role"))
    if role_value is not None:
        role = resolve_role(db, role_value)
        if role_value and role is None:
            raise HTTPException(status_code=400, detail="Invalid Role")
        row.role_id = role.id if role else None
        row.app_role = role.role_name if role else None

    manager_value = payload.get("reporting_manager_id", payload.get("reporting_manager"))
    if manager_value is not None:
        manager_text = str(manager_value or "").strip()
        manager = None
        if manager_text:
            manager = (
                db.query(EmployeeMaster)
                .filter((EmployeeMaster.id == manager_text) | (EmployeeMaster.employee_name == manager_text))
                .first()
            )
            if manager is None:
                raise HTTPException(status_code=400, detail="Invalid Reporting Manager")
        row.reporting_manager_id = manager.id if manager else None
        row.reporting_manager = manager.employee_name if manager else None


def sync_foundation_data(db: Session):
    """Idempotent seed/sync. Safe to run on every startup; never deletes business data."""
    for dep_id, dep_name in DEFAULT_DEPARTMENTS:
        row = db.query(DepartmentMaster).filter(DepartmentMaster.id == dep_id).first()
        if row is None:
            db.add(DepartmentMaster(id=dep_id, department_name=dep_name, active=True))

    for role_id, role_name, role_level in DEFAULT_ROLES:
        row = db.query(RoleMaster).filter(RoleMaster.id == role_id).first()
        if row is None:
            db.add(RoleMaster(id=role_id, role_name=role_name, role_level=role_level, active=True))

    db.flush()

    for item in DEFAULT_MODULES:
        (module_id, module_name, subtitle, department_id, parent_id, icon, route_type, route_name, form_code, display_order) = item
        row = db.query(ModuleMaster).filter(ModuleMaster.id == module_id).first()
        if row is None:
            db.add(ModuleMaster(
                id=module_id, module_name=module_name, subtitle=subtitle, department_id=department_id,
                parent_id=parent_id, icon=icon, route_type=route_type, route_name=route_name,
                form_code=form_code, display_order=display_order, active=True,
                created_at=now_local(), updated_at=now_local(),
            ))
        else:
            # Keep menu definitions current without overwriting permissions.
            row.module_name = module_name
            row.subtitle = subtitle
            row.department_id = department_id
            row.parent_id = parent_id
            row.icon = icon
            row.route_type = route_type
            row.route_name = route_name
            row.form_code = form_code
            row.display_order = display_order

    db.flush()

    # Map legacy text values to stable IDs. Existing EM01... users are preserved.
    for employee in db.query(EmployeeMaster).all():
        if not employee.department_id and employee.department:
            dep = resolve_department(db, employee.department)
            if dep:
                employee.department_id = dep.id
        if not employee.role_id and employee.app_role:
            role = resolve_role(db, employee.app_role)
            if role:
                employee.role_id = role.id
        if not employee.reporting_manager_id and employee.reporting_manager:
            manager = (
                db.query(EmployeeMaster)
                .filter(EmployeeMaster.employee_name == employee.reporting_manager)
                .first()
            )
            if manager:
                employee.reporting_manager_id = manager.id

    # Admin role receives full default access to every module.
    admin_role = resolve_role(db, "Admin")
    if admin_role:
        for module in db.query(ModuleMaster).all():
            permission = (
                db.query(RolePermission)
                .filter(RolePermission.role_id == admin_role.id, RolePermission.module_id == module.id)
                .first()
            )
            if permission is None:
                db.add(RolePermission(
                    role_id=admin_role.id, module_id=module.id, can_view=True, can_add=True,
                    can_edit=True, can_delete=True, created_at=now_local(), updated_at=now_local(),
                ))

    db.commit()


# =========================================================
# AUTHENTICATION
# =========================================================

def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Login required",
        )

    parts = authorization.split()

    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization header",
        )

    token = parts[1]

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401,
            detail="Session expired",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=401,
            detail="Invalid token",
        )

    user_id = payload.get("sub")
    token_jti = payload.get("jti")

    if not user_id or not token_jti:
        raise HTTPException(
            status_code=401,
            detail="Invalid token",
        )

    session = (
        db.query(UserSession)
        .filter(
            UserSession.user_id == user_id,
            UserSession.token_jti == token_jti,
            UserSession.revoked.is_(False),
        )
        .first()
    )

    if session is None:
        raise HTTPException(
            status_code=401,
            detail="Session not active",
        )

    user = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.id == user_id)
        .first()
    )

    if user is None or not user.active:
        raise HTTPException(
            status_code=401,
            detail="User inactive or not found",
        )

    return user


def optional_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization:
        return None

    try:
        return get_current_user(
            authorization=authorization,
            db=db,
        )
    except HTTPException:
        return None


# =========================================================
# PERMISSION ENGINE
# =========================================================

def effective_permission(
    db: Session,
    user: EmployeeMaster,
    module_id: str,
):
    result = {
        "can_view": False,
        "can_add": False,
        "can_edit": False,
        "can_delete": False,
    }

    # ADMIN gets full access
    role_text = (user.app_role or "").strip().lower()

    if user.role_id == "ROL001" or role_text in {"admin", "administrator", "super admin"}:
        return {
            "can_view": True,
            "can_add": True,
            "can_edit": True,
            "can_delete": True,
        }

    role = None

    role_value = user.role_id or user.app_role
    if role_value:
        role = resolve_role(db, role_value)

    if role:
        role_permission = (
            db.query(RolePermission)
            .filter(
                RolePermission.role_id == role.id,
                RolePermission.module_id == module_id,
            )
            .first()
        )

        if role_permission:
            result = {
                "can_view": bool(role_permission.can_view),
                "can_add": bool(role_permission.can_add),
                "can_edit": bool(role_permission.can_edit),
                "can_delete": bool(role_permission.can_delete),
            }

    override = (
        db.query(UserPermission)
        .filter(
            UserPermission.user_id == user.id,
            UserPermission.module_id == module_id,
        )
        .first()
    )

    if override:
        for key in (
            "can_view",
            "can_add",
            "can_edit",
            "can_delete",
        ):
            value = getattr(override, key)

            if value is not None:
                result[key] = bool(value)

    return result


def require_permission(
    db: Session,
    user: EmployeeMaster,
    module_id: str,
    action: str,
):
    permission = effective_permission(
        db,
        user,
        module_id,
    )

    permission_key = f"can_{action}"

    if not permission.get(permission_key, False):
        raise HTTPException(
            status_code=403,
            detail=f"{action.title()} permission denied",
        )


# =========================================================
# LOGIN
# =========================================================

@router.post("/auth/login")
def login(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
):
    login_value = str(
        payload.get("login")
        or payload.get("mobile")
        or payload.get("email")
        or ""
    ).strip()

    password = str(
        payload.get("password") or ""
    )

    if not login_value or not password:
        raise HTTPException(
            status_code=400,
            detail="Mobile/Email and Password are required",
        )

    users = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.active.is_(True))
        .all()
    )

    user = next(
        (
            item
            for item in users
            if login_value
            in {
                str(item.mobile or "").strip(),
                str(item.email or "").strip(),
                str(item.id or "").strip(),
            }
        ),
        None,
    )

    if user is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid login details",
        )

    if not verify_password(password, user.password):
        raise HTTPException(
            status_code=401,
            detail="Invalid login details",
        )

    # Upgrade old plain-text password automatically
    try:
        if not str(user.password or "").startswith("$argon2"):
            user.password = create_password_hash(password)
    except Exception:
        pass

    session_id = str(uuid.uuid4())
    token_jti = str(uuid.uuid4())

    token, expires = create_access_token(
        user.id,
        session_id,
        token_jti,
    )

    session = UserSession(
        id=session_id,
        user_id=user.id,
        token_jti=token_jti,
        device_name=payload.get("device_name"),
        created_at=now_local(),
        expires_at=expires.replace(tzinfo=None),
        revoked=False,
    )

    db.add(session)

    audit(
        db,
        user.id,
        "LOGIN",
        record_type="UserSession",
        record_id=session_id,
    )

    db.commit()

    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_at": expires.isoformat(),
        "user": {
            "id": user.id,
            "employee_name": user.employee_name,
            "mobile": user.mobile,
            "email": user.email,
            "designation": user.designation,
            "department_id": user.department_id,
            "department": user.department,
            "role_id": user.role_id,
            "role": user.app_role,
            "force_password_reset": bool(
                user.force_password_reset
            ),
        },
    }


@router.get("/auth/me")
def auth_me(
    user: EmployeeMaster = Depends(get_current_user),
):
    return {
        "id": user.id,
        "employee_name": user.employee_name,
        "mobile": user.mobile,
        "email": user.email,
        "designation": user.designation,
        "department_id": user.department_id,
        "department": user.department,
        "role_id": user.role_id,
        "role": user.app_role,
        "active": user.active,
        "force_password_reset": user.force_password_reset,
    }


@router.post("/auth/logout")
def logout(
    authorization: str = Header(...),
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token = authorization.split()[1]

    payload = jwt.decode(
        token,
        SECRET_KEY,
        algorithms=[ALGORITHM],
    )

    token_jti = payload.get("jti")

    session = (
        db.query(UserSession)
        .filter(
            UserSession.token_jti == token_jti,
            UserSession.user_id == user.id,
        )
        .first()
    )

    if session:
        session.revoked = True

    audit(
        db,
        user.id,
        "LOGOUT",
    )

    db.commit()

    return {
        "success": True,
        "message": "Logged out successfully",
    }


@router.post("/auth/change-password")
def change_password(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    old_password = str(
        payload.get("old_password") or ""
    )

    new_password = str(
        payload.get("new_password") or ""
    )

    if not verify_password(
        old_password,
        user.password,
    ):
        raise HTTPException(
            status_code=400,
            detail="Current password is incorrect",
        )

    if len(new_password) < 6:
        raise HTTPException(
            status_code=400,
            detail="New password must be at least 6 characters",
        )

    user.password = create_password_hash(new_password)
    user.force_password_reset = False

    audit(
        db,
        user.id,
        "CHANGE_PASSWORD",
        record_type="EmployeeMaster",
        record_id=user.id,
    )

    db.commit()

    return {
        "success": True,
        "message": "Password changed successfully",
    }


# =========================================================
# INITIAL SETUP
#
# Run ONCE before login system is active.
# Creates departments, roles, modules and first admin.
# =========================================================

DEFAULT_DEPARTMENTS = [
    ("DEP001", "Management"),
    ("DEP002", "Sales & Marketing"),
    ("DEP003", "New Installation"),
    ("DEP004", "Repair & Modification"),
    ("DEP005", "AMC & Service"),
    ("DEP006", "Production"),
    ("DEP007", "Accounts & Official"),
    ("DEP008", "Back Office"),
    ("DEP009", "Performance"),
]

DEFAULT_ROLES = [
    ("ROL001", "Admin", 1),
    ("ROL002", "Department Head", 2),
    ("ROL003", "Manager", 3),
    ("ROL004", "Supervisor", 4),
    ("ROL005", "Executive", 5),
    ("ROL006", "Technician", 6),
    ("ROL007", "Viewer", 7),
]

DEFAULT_MODULES = [
    (
        "dashboard",
        "Dashboard",
        "Business KPI & overview",
        None,
        None,
        "dashboard",
        "page",
        "dashboard",
        None,
        1,
    ),
    (
        "sales_marketing",
        "Sales & Marketing",
        "Lead, follow-up, target & marketing",
        "DEP002",
        None,
        "sales",
        "submenu",
        None,
        None,
        10,
    ),
    (
        "lead_entry",
        "Lead Entry",
        "Create a new sales lead",
        "DEP002",
        "sales_marketing",
        "add",
        "form",
        None,
        "lead_entry",
        11,
    ),
    (
        "all_leads",
        "All Leads",
        "View & search all sales leads",
        "DEP002",
        "sales_marketing",
        "list",
        "page",
        "all_leads",
        None,
        12,
    ),
    (
        "lead_update",
        "Lead Update",
        "Update existing leads",
        "DEP002",
        "sales_marketing",
        "edit",
        "page",
        "lead_update",
        None,
        13,
    ),
    (
        "follow_up",
        "Follow-up",
        "Monthly, missed & custom follow-up",
        "DEP002",
        "sales_marketing",
        "followup",
        "page",
        "follow_up",
        None,
        14,
    ),
    (
        "targets",
        "Targets",
        "Sales target & achievement",
        "DEP002",
        "sales_marketing",
        "target",
        "page",
        "targets",
        None,
        15,
    ),
    (
        "marketing_reports",
        "Marketing Reports",
        "Pipeline activity reports",
        "DEP002",
        "sales_marketing",
        "report",
        "page",
        "marketing_reports",
        None,
        16,
    ),
    (
        "new_installation",
        "New Installation",
        "Installation projects & progress",
        "DEP003",
        None,
        "installation",
        "submenu",
        None,
        None,
        20,
    ),
    (
        "repair_modification",
        "Repair & Modification",
        "Repair and modernization jobs",
        "DEP004",
        None,
        "repair",
        "submenu",
        None,
        None,
        30,
    ),
    (
        "amc_service",
        "AMC & Service",
        "AMC, PM & breakdown management",
        "DEP005",
        None,
        "service",
        "submenu",
        None,
        None,
        40,
    ),
    (
        "production",
        "Production",
        "Production & material management",
        "DEP006",
        None,
        "production",
        "submenu",
        None,
        None,
        50,
    ),
    (
        "accounts_official",
        "Accounts & Official",
        "Accounts and official activities",
        "DEP007",
        None,
        "accounts",
        "submenu",
        None,
        None,
        60,
    ),
    (
        "back_office",
        "Back Office",
        "Back office operations",
        "DEP008",
        None,
        "office",
        "submenu",
        None,
        None,
        70,
    ),
    (
        "performance",
        "Performance",
        "Employee performance",
        "DEP009",
        None,
        "performance",
        "submenu",
        None,
        None,
        80,
    ),
    (
        "reports",
        "Reports",
        "Business reports",
        None,
        None,
        "report",
        "submenu",
        None,
        None,
        90,
    ),
    (
        "settings",
        "Settings",
        "Users, permissions & master data",
        "DEP001",
        None,
        "settings",
        "submenu",
        None,
        None,
        100,
    ),
    (
        "user_management",
        "User Management",
        "Create and manage users",
        "DEP001",
        "settings",
        "users",
        "page",
        "user_management",
        None,
        101,
    ),
    (
        "role_management",
        "Role Management",
        "Manage application roles",
        "DEP001",
        "settings",
        "role",
        "page",
        "role_management",
        None,
        102,
    ),
    (
        "permission_management",
        "Permissions",
        "View, Add, Edit & Delete access",
        "DEP001",
        "settings",
        "permission",
        "page",
        "permission_management",
        None,
        103,
    ),
    (
        "data_master",
        "Data Master",
        "Single & bulk master data",
        "DEP001",
        "settings",
        "database",
        "page",
        "data_master",
        None,
        104,
    ),
]


@router.post("/setup/initialize")
def initialize_system(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
):
    # Create/sync Departments, Roles, Modules and Admin permissions.
    sync_foundation_data(db)

    # Do not allow initialization again once an Admin with password exists.
    existing_admin = (
        db.query(EmployeeMaster)
        .filter(
            (EmployeeMaster.role_id == "ROL001")
            | (EmployeeMaster.app_role == "Admin")
        )
        .first()
    )

    if existing_admin is not None and existing_admin.password:
        raise HTTPException(
            status_code=400,
            detail="System already initialized",
        )

    user_id = str(payload.get("id") or "EM01").strip()
    employee_name = str(payload.get("employee_name") or "").strip()
    mobile = str(payload.get("mobile") or "").strip()
    email = str(payload.get("email") or "").strip()
    password = str(payload.get("password") or "")

    if not employee_name:
        raise HTTPException(
            status_code=400,
            detail="Admin employee name is required",
        )

    if not mobile:
        raise HTTPException(
            status_code=400,
            detail="Admin mobile number is required",
        )

    if len(password) < 6:
        raise HTTPException(
            status_code=400,
            detail="Admin password must be at least 6 characters",
        )

    # Check whether requested Employee ID already exists.
    target = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.id == user_id)
        .first()
    )

    # Fresh PostgreSQL database: create the first employee/admin.
    if target is None:
        target = EmployeeMaster(
            id=user_id,
            employee_name=employee_name,
            mobile=mobile,
            email=email or None,
            designation="Administrator",
            active=True,
            password=create_password_hash(password),
            force_password_reset=False,
            date_of_joining=now_local(),
        )

        db.add(target)
        db.flush()

    else:
        # Existing employee without initialized password can become first Admin.
        if target.password:
            raise HTTPException(
                status_code=400,
                detail="This employee already has a password",
            )

        target.employee_name = employee_name
        target.mobile = mobile
        target.email = email or None
        target.active = True
        target.password = create_password_hash(password)
        target.force_password_reset = False

        if not target.date_of_joining:
            target.date_of_joining = now_local()

    # Make first user Management/Admin.
    apply_user_master_refs(
        db,
        target,
        {
            "department_id": "DEP001",
            "role_id": "ROL001",
        },
    )

    audit(
        db,
        target.id,
        "INITIALIZE_ADMIN",
        "user_management",
        "EmployeeMaster",
        target.id,
    )

    db.commit()
    db.refresh(target)

    return {
        "success": True,
        "message": "Dorado CRM initialized successfully",
        "admin_id": target.id,
    }


# =========================================================
# DEPARTMENTS
# =========================================================

@router.get("/admin/departments")
def list_departments(
    db: Session = Depends(get_db),
):
    rows = (
        db.query(DepartmentMaster)
        .order_by(DepartmentMaster.department_name)
        .all()
    )

    return [model_to_dict(row) for row in rows]


@router.post("/admin/departments")
def create_department(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "settings",
        "add",
    )

    department_id = str(
        payload.get("id") or ""
    ).strip()

    name = str(
        payload.get("department_name") or ""
    ).strip()

    if not department_id or not name:
        raise HTTPException(
            status_code=400,
            detail="Department ID and Name are required",
        )

    if (
        db.query(DepartmentMaster)
        .filter(DepartmentMaster.id == department_id)
        .first()
    ):
        raise HTTPException(
            status_code=400,
            detail="Department ID already exists",
        )

    row = DepartmentMaster(
        id=department_id,
        department_name=name,
        active=bool(payload.get("active", True)),
    )

    db.add(row)

    audit(
        db,
        user.id,
        "ADD",
        "settings",
        "Department",
        department_id,
        name,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


@router.put("/admin/departments/{department_id}")
def update_department(
    department_id: str,
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "settings",
        "edit",
    )

    row = (
        db.query(DepartmentMaster)
        .filter(DepartmentMaster.id == department_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Department not found",
        )

    if "department_name" in payload:
        row.department_name = str(
            payload["department_name"]
        ).strip()

    if "active" in payload:
        row.active = bool(payload["active"])

    audit(
        db,
        user.id,
        "EDIT",
        "settings",
        "Department",
        department_id,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


# =========================================================
# ROLES
# =========================================================

@router.get("/admin/roles")
def list_roles(
    db: Session = Depends(get_db),
):
    rows = (
        db.query(RoleMaster)
        .order_by(RoleMaster.role_level, RoleMaster.role_name)
        .all()
    )

    return [model_to_dict(row) for row in rows]


@router.post("/admin/roles")
def create_role(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "settings",
        "add",
    )

    role_id = str(payload.get("id") or "").strip()
    role_name = str(
        payload.get("role_name") or ""
    ).strip()

    if not role_id or not role_name:
        raise HTTPException(
            status_code=400,
            detail="Role ID and Role Name are required",
        )

    if (
        db.query(RoleMaster)
        .filter(RoleMaster.id == role_id)
        .first()
    ):
        raise HTTPException(
            status_code=400,
            detail="Role ID already exists",
        )

    row = RoleMaster(
        id=role_id,
        role_name=role_name,
        role_level=payload.get("role_level"),
        active=bool(payload.get("active", True)),
    )

    db.add(row)

    audit(
        db,
        user.id,
        "ADD",
        "settings",
        "Role",
        role_id,
        role_name,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


@router.put("/admin/roles/{role_id}")
def update_role(
    role_id: str,
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "settings",
        "edit",
    )

    row = (
        db.query(RoleMaster)
        .filter(RoleMaster.id == role_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Role not found",
        )

    for field in (
        "role_name",
        "role_level",
        "active",
    ):
        if field in payload:
            setattr(row, field, payload[field])

    audit(
        db,
        user.id,
        "EDIT",
        "settings",
        "Role",
        role_id,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)

class CreateUserRequest(BaseModel):
    id: str
    employee_name: str
    password: str

    mobile: str | None = None
    email: str | None = None
    designation: str | None = None

    department_id: str | None = None
    role_id: str | None = None
    reporting_manager_id: str | None = None

    active: bool = True
    force_password_reset: bool = True

# =========================================================
# USERS
# =========================================================

@router.get("/admin/users")
def list_users(
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "user_management",
        "view",
    )

    rows = (
        db.query(EmployeeMaster)
        .order_by(EmployeeMaster.employee_name)
        .all()
    )

    result = []

    for row in rows:
        data = model_to_dict(row)
        data.pop("password", None)
        result.append(data)

    return result

@router.get("/admin/next-user-id")
def get_next_user_id(
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "user_management",
        "view",
    )

    employees = db.query(EmployeeMaster).all()

    max_number = 0

    for employee in employees:
        employee_id = str(employee.id or "").strip().upper()

        if employee_id.startswith("EM"):
            try:
                number = int(employee_id[2:])
                if number > max_number:
                    max_number = number
            except ValueError:
                pass

    next_number = max_number + 1

    return {
        "next_id": f"EM{next_number:02d}"
    }

@router.post("/admin/users")
def create_user(
    payload: CreateUserRequest,
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payload = payload.model_dump()
    require_permission(
        db,
        user,
        "user_management",
        "add",
    )

    user_id = str(
        payload.get("id") or ""
    ).strip()

    employee_name = str(
        payload.get("employee_name") or ""
    ).strip()

    password = str(
        payload.get("password") or ""
    )

    if not user_id or not employee_name:
        raise HTTPException(
            status_code=400,
            detail="User ID and Employee Name are required",
        )

    if len(password) < 6:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 6 characters",
        )

    if (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.id == user_id)
        .first()
    ):
        raise HTTPException(
            status_code=400,
            detail="User ID already exists",
        )

    row = EmployeeMaster(
        id=user_id,
        employee_name=employee_name,
        email=payload.get("email"),
        designation=payload.get("designation"),
        mobile=payload.get("mobile"),
        active=bool(payload.get("active", True)),
        password=create_password_hash(password),
        force_password_reset=bool(payload.get("force_password_reset", True)),
        date_of_joining=now_local(),
    )
    apply_user_master_refs(db, row, payload)

    db.add(row)

    audit(
        db,
        user.id,
        "ADD",
        "user_management",
        "EmployeeMaster",
        user_id,
        employee_name,
    )

    db.commit()
    db.refresh(row)

    data = model_to_dict(row)
    data.pop("password", None)

    return data


@router.put("/admin/users/{user_id}")
def update_user(
    user_id: str,
    payload: dict[str, Any],
    current_user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        current_user,
        "user_management",
        "edit",
    )

    row = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.id == user_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    editable = {
        "employee_name", "email", "designation", "mobile",
        "active", "force_password_reset",
    }

    for key, value in payload.items():
        if key in editable:
            setattr(row, key, value)

    apply_user_master_refs(db, row, payload)

    if payload.get("password"):
        password = str(payload["password"])

        if len(password) < 6:
            raise HTTPException(
                status_code=400,
                detail="Password must be at least 6 characters",
            )

        row.password = create_password_hash(password)

    audit(
        db,
        current_user.id,
        "EDIT",
        "user_management",
        "EmployeeMaster",
        user_id,
    )

    db.commit()
    db.refresh(row)

    data = model_to_dict(row)
    data.pop("password", None)

    return data


@router.delete("/admin/users/{user_id}")
def deactivate_user(
    user_id: str,
    current_user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        current_user,
        "user_management",
        "delete",
    )

    if user_id == current_user.id:
        raise HTTPException(
            status_code=400,
            detail="You cannot deactivate your own account",
        )

    row = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.id == user_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    # Safer than physical delete
    row.active = False

    sessions = (
        db.query(UserSession)
        .filter(UserSession.user_id == user_id)
        .all()
    )

    for session in sessions:
        session.revoked = True

    audit(
        db,
        current_user.id,
        "DEACTIVATE",
        "user_management",
        "EmployeeMaster",
        user_id,
    )

    db.commit()

    return {
        "success": True,
        "message": "User deactivated successfully",
    }


# =========================================================
# MODULES
# =========================================================

@router.get("/admin/modules")
def list_modules(
    db: Session = Depends(get_db),
):
    rows = (
        db.query(ModuleMaster)
        .order_by(ModuleMaster.display_order)
        .all()
    )

    return [model_to_dict(row) for row in rows]


@router.post("/admin/modules")
def create_module(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "settings",
        "add",
    )

    module_id = str(
        payload.get("id") or ""
    ).strip()

    module_name = str(
        payload.get("module_name") or ""
    ).strip()

    if not module_id or not module_name:
        raise HTTPException(
            status_code=400,
            detail="Module ID and Module Name are required",
        )

    if (
        db.query(ModuleMaster)
        .filter(ModuleMaster.id == module_id)
        .first()
    ):
        raise HTTPException(
            status_code=400,
            detail="Module ID already exists",
        )

    row = ModuleMaster(
        id=module_id,
        module_name=module_name,
        subtitle=payload.get("subtitle"),
        department_id=payload.get("department_id"),
        parent_id=payload.get("parent_id"),
        icon=payload.get("icon"),
        route_type=payload.get(
            "route_type",
            "page",
        ),
        route_name=payload.get("route_name"),
        form_code=payload.get("form_code"),
        display_order=int(
            payload.get("display_order", 0)
        ),
        active=bool(payload.get("active", True)),
        created_at=now_local(),
        updated_at=now_local(),
    )

    db.add(row)

    audit(
        db,
        user.id,
        "ADD",
        "settings",
        "Module",
        module_id,
        module_name,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


# =========================================================
# ROLE PERMISSIONS
# =========================================================

@router.get("/admin/permissions/roles/{role_id}")
def get_role_permissions(
    role_id: str,
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "permission_management",
        "view",
    )

    modules = (
        db.query(ModuleMaster)
        .filter(ModuleMaster.active.is_(True))
        .order_by(ModuleMaster.display_order)
        .all()
    )

    result = []

    for module in modules:
        permission = (
            db.query(RolePermission)
            .filter(
                RolePermission.role_id == role_id,
                RolePermission.module_id == module.id,
            )
            .first()
        )

        result.append(
            {
                "module_id": module.id,
                "module_name": module.module_name,
                "parent_id": module.parent_id,
                "can_view": bool(
                    permission.can_view
                    if permission
                    else False
                ),
                "can_add": bool(
                    permission.can_add
                    if permission
                    else False
                ),
                "can_edit": bool(
                    permission.can_edit
                    if permission
                    else False
                ),
                "can_delete": bool(
                    permission.can_delete
                    if permission
                    else False
                ),
            }
        )

    return result


@router.put("/admin/permissions/roles/{role_id}/{module_id}")
def save_role_permission(
    role_id: str,
    module_id: str,
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "permission_management",
        "edit",
    )

    row = (
        db.query(RolePermission)
        .filter(
            RolePermission.role_id == role_id,
            RolePermission.module_id == module_id,
        )
        .first()
    )

    if row is None:
        row = RolePermission(
            role_id=role_id,
            module_id=module_id,
            created_at=now_local(),
            updated_at=now_local(),
        )

        db.add(row)

    row.can_view = bool(
        payload.get("can_view", False)
    )
    row.can_add = bool(
        payload.get("can_add", False)
    )
    row.can_edit = bool(
        payload.get("can_edit", False)
    )
    row.can_delete = bool(
        payload.get("can_delete", False)
    )

    row.updated_at = now_local()

    audit(
        db,
        user.id,
        "PERMISSION_UPDATE",
        "permission_management",
        "RolePermission",
        f"{role_id}:{module_id}",
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


# =========================================================
# USER PERMISSION OVERRIDE
# =========================================================

@router.put("/admin/permissions/users/{user_id}/{module_id}")
def save_user_permission(
    user_id: str,
    module_id: str,
    payload: dict[str, Any],
    current_user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        current_user,
        "permission_management",
        "edit",
    )

    row = (
        db.query(UserPermission)
        .filter(
            UserPermission.user_id == user_id,
            UserPermission.module_id == module_id,
        )
        .first()
    )

    if row is None:
        row = UserPermission(
            user_id=user_id,
            module_id=module_id,
            created_at=now_local(),
            updated_at=now_local(),
        )

        db.add(row)

    for key in (
        "can_view",
        "can_add",
        "can_edit",
        "can_delete",
    ):
        if key in payload:
            setattr(row, key, payload[key])

    row.updated_at = now_local()

    audit(
        db,
        current_user.id,
        "USER_PERMISSION_UPDATE",
        "permission_management",
        "UserPermission",
        f"{user_id}:{module_id}",
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


# =========================================================
# DYNAMIC MENU FOR LOGGED-IN USER
# =========================================================

@router.get("/user/menu")
def user_menu(
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    modules = (
        db.query(ModuleMaster)
        .filter(ModuleMaster.active.is_(True))
        .order_by(ModuleMaster.display_order)
        .all()
    )

    visible = []

    for module in modules:
        permission = effective_permission(
            db,
            user,
            module.id,
        )

        if permission["can_view"]:
            visible.append(
                {
                    "id": module.id,
                    "title": module.module_name,
                    "subtitle": module.subtitle or "",
                    "icon": module.icon or "",
                    "routeType": module.route_type,
                    "routeName": module.route_name or "",
                    "formCode": module.form_code or "",
                    "parentId": module.parent_id,
                    "permission": permission,
                }
            )

    top_level = []

    for module in visible:
        if module["parentId"] is not None:
            continue

        children = [
            child
            for child in visible
            if child["parentId"] == module["id"]
        ]

        item = dict(module)
        item["children"] = children
        top_level.append(item)

    return top_level


# =========================================================
# MASTER TYPES
# =========================================================

@router.get("/admin/master-types")
def list_master_types(
    db: Session = Depends(get_db),
):
    rows = (
        db.query(MasterType)
        .order_by(
            MasterType.display_order,
            MasterType.master_name,
        )
        .all()
    )

    return [model_to_dict(row) for row in rows]


@router.post("/admin/master-types")
def create_master_type(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "data_master",
        "add",
    )

    type_id = str(
        payload.get("id") or ""
    ).strip().upper()

    name = str(
        payload.get("master_name") or ""
    ).strip()

    if not type_id or not name:
        raise HTTPException(
            status_code=400,
            detail="Master Type ID and Name are required",
        )

    if (
        db.query(MasterType)
        .filter(MasterType.id == type_id)
        .first()
    ):
        raise HTTPException(
            status_code=400,
            detail="Master Type already exists",
        )

    row = MasterType(
        id=type_id,
        master_name=name,
        department_id=payload.get("department_id"),
        description=payload.get("description"),
        allow_global=bool(
            payload.get("allow_global", False)
        ),
        display_order=int(
            payload.get("display_order", 0)
        ),
        active=bool(payload.get("active", True)),
        created_at=now_local(),
        updated_at=now_local(),
    )

    db.add(row)

    audit(
        db,
        user.id,
        "ADD",
        "data_master",
        "MasterType",
        type_id,
        name,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


# =========================================================
# MASTER DATA
# =========================================================

@router.get("/master-data/{master_type_id}")
def list_master_data(
    master_type_id: str,
    department_id: str | None = None,
    active_only: bool = True,
    db: Session = Depends(get_db),
):
    query = db.query(MasterData).filter(
        MasterData.master_type_id == master_type_id
    )

    if department_id:
        query = query.filter(
            MasterData.department_id.in_(
                [department_id, "GLOBAL"]
            )
        )

    if active_only:
        query = query.filter(
            MasterData.active.is_(True)
        )

    rows = query.order_by(
        MasterData.display_order,
        MasterData.name,
    ).all()

    return [model_to_dict(row) for row in rows]


@router.post("/admin/master-data")
def add_master_data(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "data_master",
        "add",
    )

    master_type_id = str(
        payload.get("master_type_id") or ""
    ).strip().upper()

    code = str(
        payload.get("code") or ""
    ).strip().upper()

    name = str(
        payload.get("name") or ""
    ).strip()

    department_id = (
        str(payload.get("department_id")).strip()
        if payload.get("department_id")
        else None
    )

    if not master_type_id or not code or not name:
        raise HTTPException(
            status_code=400,
            detail="Master Type, Code and Name are required",
        )

    master_type = (
        db.query(MasterType)
        .filter(MasterType.id == master_type_id)
        .first()
    )

    if master_type is None:
        raise HTTPException(
            status_code=404,
            detail="Master Type not found",
        )

    existing = (
        db.query(MasterData)
        .filter(
            MasterData.master_type_id == master_type_id,
            MasterData.department_id == department_id,
            MasterData.code == code,
        )
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=400,
            detail="Master data code already exists",
        )

    row = MasterData(
        master_type_id=master_type_id,
        department_id=department_id,
        code=code,
        name=name,
        description=payload.get("description"),
        extra_data=payload.get("extra_data"),
        display_order=int(
            payload.get("display_order", 0)
        ),
        active=bool(payload.get("active", True)),
        created_by=user.id,
        created_at=now_local(),
        updated_by=user.id,
        updated_at=now_local(),
    )

    db.add(row)

    audit(
        db,
        user.id,
        "ADD",
        "data_master",
        "MasterData",
        code,
        name,
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


# =========================================================
# BULK MASTER DATA
# =========================================================

@router.post("/admin/master-data/bulk")
def bulk_add_master_data(
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "data_master",
        "add",
    )

    master_type_id = str(
        payload.get("master_type_id") or ""
    ).strip().upper()

    department_id = (
        str(payload.get("department_id")).strip()
        if payload.get("department_id")
        else None
    )

    items = payload.get("items") or []

    if not master_type_id:
        raise HTTPException(
            status_code=400,
            detail="Master Type is required",
        )

    if not isinstance(items, list) or not items:
        raise HTTPException(
            status_code=400,
            detail="Bulk items are required",
        )

    master_type = (
        db.query(MasterType)
        .filter(MasterType.id == master_type_id)
        .first()
    )

    if master_type is None:
        raise HTTPException(
            status_code=404,
            detail="Master Type not found",
        )

    created = []
    skipped = []

    for index, item in enumerate(items, start=1):
        name = str(
            item.get("name") or ""
        ).strip()

        code = str(
            item.get("code")
            or f"{master_type_id}-{index:03d}"
        ).strip().upper()

        if not name:
            skipped.append(
                {
                    "code": code,
                    "reason": "Name blank",
                }
            )
            continue

        existing = (
            db.query(MasterData)
            .filter(
                MasterData.master_type_id
                == master_type_id,
                MasterData.department_id
                == department_id,
                MasterData.code == code,
            )
            .first()
        )

        if existing:
            skipped.append(
                {
                    "code": code,
                    "reason": "Already exists",
                }
            )
            continue

        row = MasterData(
            master_type_id=master_type_id,
            department_id=department_id,
            code=code,
            name=name,
            description=item.get("description"),
            extra_data=item.get("extra_data"),
            display_order=int(
                item.get("display_order", index)
            ),
            active=bool(
                item.get("active", True)
            ),
            created_by=user.id,
            created_at=now_local(),
            updated_by=user.id,
            updated_at=now_local(),
        )

        db.add(row)

        created.append(
            {
                "code": code,
                "name": name,
            }
        )

    audit(
        db,
        user.id,
        "BULK_ADD",
        "data_master",
        "MasterData",
        master_type_id,
        f"{len(created)} records",
    )

    db.commit()

    return {
        "success": True,
        "created_count": len(created),
        "skipped_count": len(skipped),
        "created": created,
        "skipped": skipped,
    }


@router.put("/admin/master-data/{record_id}")
def update_master_data(
    record_id: int,
    payload: dict[str, Any],
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "data_master",
        "edit",
    )

    row = (
        db.query(MasterData)
        .filter(MasterData.id == record_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Master data not found",
        )

    editable = {
        "department_id",
        "code",
        "name",
        "description",
        "extra_data",
        "display_order",
        "active",
    }

    for key, value in payload.items():
        if key in editable:
            setattr(row, key, value)

    row.updated_by = user.id
    row.updated_at = now_local()

    audit(
        db,
        user.id,
        "EDIT",
        "data_master",
        "MasterData",
        str(record_id),
    )

    db.commit()
    db.refresh(row)

    return model_to_dict(row)


@router.delete("/admin/master-data/{record_id}")
def deactivate_master_data(
    record_id: int,
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "data_master",
        "delete",
    )

    row = (
        db.query(MasterData)
        .filter(MasterData.id == record_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Master data not found",
        )

    row.active = False
    row.updated_by = user.id
    row.updated_at = now_local()

    audit(
        db,
        user.id,
        "DEACTIVATE",
        "data_master",
        "MasterData",
        str(record_id),
    )

    db.commit()

    return {
        "success": True,
        "message": "Master data deactivated",
    }


# =========================================================
# DASHBOARD
# =========================================================

@router.get("/dashboard/summary")
def dashboard_summary(
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(
        db,
        user,
        "dashboard",
        "view",
    )

    leads = db.query(Lead).filter(
        Lead.active.is_(True)
    ).all()

    total_leads = len(leads)

    orders = [
        lead
        for lead in leads
        if lead.order_finalized is True
    ]

    order_value = sum(
        float(lead.order_value or 0)
        for lead in orders
    )

    return {
        "total_leads": total_leads,
        "follow_ups": sum(
            1
            for lead in leads
            if lead.follow_up_date is not None
        ),
        "appointments": sum(
            1
            for lead in leads
            if lead.appointment_fixed is True
        ),
        "site_visits": sum(
            1
            for lead in leads
            if lead.site_visit_done is True
        ),
        "surveys": sum(
            1
            for lead in leads
            if lead.survey_done is True
        ),
        "quotations": sum(
            1
            for lead in leads
            if lead.quotation_given is True
        ),
        "orders": len(orders),
        "order_value": order_value,
    }
# =========================================================
# USER FORM MASTER OPTIONS
# Department / Role / Reporting Manager from Database
# =========================================================

@router.get("/admin/user-form-options")
def user_form_options(
    user: EmployeeMaster = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    require_permission(db, user, "user_management", "view")
    departments = (
        db.query(DepartmentMaster)
        .filter(DepartmentMaster.active.is_(True))
        .order_by(DepartmentMaster.department_name)
        .all()
    )

    roles = (
        db.query(RoleMaster)
        .filter(RoleMaster.active.is_(True))
        .order_by(
            RoleMaster.role_level,
            RoleMaster.role_name,
        )
        .all()
    )

    employees = (
        db.query(EmployeeMaster)
        .filter(EmployeeMaster.active.is_(True))
        .order_by(EmployeeMaster.employee_name)
        .all()
    )

    return {
        "departments": [
            {
                "id": row.id,
                "name": row.department_name,
            }
            for row in departments
        ],

        "roles": [
            {
                "id": row.id,
                "name": row.role_name,
                "level": row.role_level,
            }
            for row in roles
        ],

        "reporting_managers": [
            {
                "id": row.id,
                "name": row.employee_name,
                "designation": row.designation,
                "department": row.department,
            }
            for row in employees
        ],
    }