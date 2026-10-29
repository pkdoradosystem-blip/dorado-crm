
import json
from io import BytesIO
from decimal import Decimal, InvalidOperation
from docxtpl import DocxTemplate


def as_dict(value):
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value.strip():
        try:
            result = json.loads(value)
            return result if isinstance(result, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def amount(value):
    try:
        result = Decimal(str(value or 0))
        if not result.is_finite() or result < 0:
            raise ValueError("Invalid upgrade amount")
        return result
    except (InvalidOperation, ValueError):
        raise ValueError("Invalid price or upgrade amount")


def selected(value):
    return value is True or str(value).strip().lower() in (
        "yes", "true", "1", "selected"
    )


def build_word_quotation(quotation, template_bytes):
    commercial = as_dict(quotation.commercial_data)
    technical = as_dict(quotation.technical_data)

    base_price = amount(
        commercial.get(
            "price_including_gst",
            quotation.grand_total
        )
    )

    upgrades = {}

    for key in ("auto_door", "ss_cabin", "ard"):
        is_selected = selected(
            commercial.get(f"{key}_selected", False)
        )

        addon = amount(
            commercial.get(f"{key}_addon", 0)
        )

        upgrades[key] = addon if is_selected else Decimal("0")

    final_price = base_price + sum(
        upgrades.values(), Decimal("0")
    )

    context = {
        "quotation_no": quotation.quotation_no,
        "quotation_date": (
            quotation.quotation_date.strftime("%d-%m-%Y")
            if quotation.quotation_date else ""
        ),
        "customer_name": quotation.customer_name or "",
        "site_address": quotation.site_address or "",
        "office_address": quotation.office_address or "",
        "mobile": quotation.mobile or "",
        "location": quotation.location or "",
        "base_price_including_gst": f"{base_price:,.2f}",
        "auto_door_addon": f"{amount(commercial.get('auto_door_addon')):,.2f}",
        "ss_cabin_addon": f"{amount(commercial.get('ss_cabin_addon')):,.2f}",
        "ard_addon": f"{amount(commercial.get('ard_addon')):,.2f}",
        "auto_door_selected": "YES" if selected(
            commercial.get("auto_door_selected")
        ) else "NO",
        "ss_cabin_selected": "YES" if selected(
            commercial.get("ss_cabin_selected")
        ) else "NO",
        "ard_selected": "YES" if selected(
            commercial.get("ard_selected")
        ) else "NO",
        "selected_auto_door_amount": f"{upgrades['auto_door']:,.2f}",
        "selected_ss_cabin_amount": f"{upgrades['ss_cabin']:,.2f}",
        "selected_ard_amount": f"{upgrades['ard']:,.2f}",
        "final_price_including_gst": f"{final_price:,.2f}",
        "license_fee": commercial.get("license_fee", ""),
        "quotation_validity": commercial.get("quotation_validity", ""),
        "cabin_model_no": commercial.get("cabin_model_no", ""),
        "payment_terms": quotation.payment_terms or "",
        "delivery_period": quotation.delivery_period or "",
        "warranty_terms": quotation.warranty_terms or "",
    }

    # Make technical and commercial fields available
    # to Word templates without overwriting core values.
    for key, value in technical.items():
        context.setdefault(key, value)

    for key, value in commercial.items():
        context.setdefault(key, value)


    # -----------------------------------------------
    # DORADO TECHNICAL FIELD MAPPING
    # -----------------------------------------------
    aliases = {
        "capacity": "person_capacity",
        "passenger_capacity": "person_capacity",
        "no_of_passengers": "person_capacity",
        "floor_rise": "number_of_floor",
        "travel_stops": "number_of_floor",
        "number_of_stops": "no_of_stops",
        "number_of_openings": "no_of_opening",
        "car_travel": "total_height",
        "landing_entrance": "landing_door_type",
        "landing_door": "landing_door_type",
        "car_entrance_door": "car_door_type",
        "cabin_finish": "car_enclosure",
        "base_cabin_finish": "car_enclosure",
        "base_landing_door": "landing_door_type",
        "clear_door_opening": "entrance_opening",
        "reduction_gear_motor": "gear_motor_machine",
        "wire_ropes": "wire_rope",
        "lift_well": "shaft_width",
        "no_of_unit": "number_of_unit",
    }

    for word_field, crm_field in aliases.items():
        if not context.get(word_field):
            context[word_field] = technical.get(crm_field, "")

    # Values derived from existing technical snapshot.
    capacity = technical.get("person_capacity")
    if capacity:
        context["capacity_display"] = str(capacity) + " passengers"
        context["lift_capacity"] = capacity

    context["lift_type"] = technical.get("lift_type", "")
    context["floor_rise"] = technical.get("number_of_floor", "")
    context["no_of_stops"] = technical.get("no_of_stops", "")
    context["no_of_openings"] = technical.get("no_of_opening", "")
    context["door_operation"] = technical.get("door_operation", "")
    context["machine_room_position"] = technical.get(
        "machine_room_position", ""
    )

    context["customer_address"] = (
        quotation.site_address
        or quotation.office_address
        or ""
    )

    context["site_location"] = (
        quotation.location
        or quotation.site_address
        or ""
    )

    context["cabin_model"] = commercial.get(
        "cabin_model_no", ""
    )

    context["offer_validity_days"] = commercial.get(
        "quotation_validity", ""
    )

    context["delivery_weeks"] = commercial.get(
        "delivery_weeks", ""
    )

    context["installation_weeks"] = commercial.get(
        "installation_weeks", ""
    )

    # Keep load blank unless an actual rated load is stored.
    context["load"] = technical.get("load", "")
    context["rated_load"] = technical.get("rated_load", "")


    # -----------------------------------------------
    # DORADO COMPLETE FIELD MAPPING
    # -----------------------------------------------
    extra_aliases = {
        "control": "control",
        "no_of_stops": "no_of_stops",
        "no_of_openings": "no_of_opening",
        "number_of_openings": "no_of_opening",
        "landing_entrance": "landing_door_type",
        "base_landing_door": "landing_door_type",
        "car_entrance_door": "car_door_type",
        "clear_door_opening": "entrance_opening",
        "reduction_gear_motor": "gear_motor_machine",
        "wire_ropes": "wire_rope",
        "installation": "installation",
        "operation": "door_operation",
        "car_travel": "total_height",
        "travel_stops": "number_of_floor",
        "ard": "ard_required",
    }

    for word_key, crm_key in extra_aliases.items():
        value = technical.get(crm_key)
        if value is not None and str(value).strip():
            context[word_key] = value

    # Combined shaft dimensions
    shaft_width = technical.get("shaft_width")
    shaft_depth = technical.get("shaft_depth")

    if shaft_width and shaft_depth:
        context["lift_well"] = (
            f"{shaft_width} x {shaft_depth} mm"
        )

    # Display-friendly values
    context["travel_stops"] = (
        str(technical.get("number_of_floor", ""))
        + " / "
        + str(technical.get("no_of_stops", ""))
    )

    context["base_elevator_description"] = (
        str(technical.get("person_capacity", ""))
        + " Passenger "
        + str(technical.get("lift_type", ""))
        + ", "
        + str(technical.get("number_of_floor", ""))
    )

    context["base_specification"] = (
        str(technical.get("landing_door_type", ""))
        + " / "
        + str(technical.get("car_enclosure", ""))
    )


    # DORADO EXACT TEMPLATE PLACEHOLDERS
    exact_fields = {
        "capacity": "person_capacity",
        "travel": "number_of_floor",
        "stops": "no_of_stops",
        "openings": "no_of_opening",
        "control_type": "control",
        "base_door_type": "landing_door_type",
        "base_cabin_finish": "car_enclosure",
        "car_door": "car_door_type",
        "clear_opening": "entrance_opening",
        "machine": "gear_motor_machine",
        "ropes": "wire_rope",
        "installation_type": "installation",
        "ard_yes_no": "ard_required",
        "base_ard_status": "ard_required",
        "operation": "door_operation",
    }

    for word_key, crm_key in exact_fields.items():
        value = technical.get(crm_key)
        if value is not None:
            context[word_key] = value

    width = technical.get("shaft_width")
    depth = technical.get("shaft_depth")
    if width and depth:
        context["lift_well"] = f"{width} x {depth} mm"

    capacity = technical.get("person_capacity", "")
    lift_type = technical.get("lift_type", "")
    floor = technical.get("number_of_floor", "")

    context["base_lift_description"] = (
        f"{capacity} Passenger {lift_type}, {floor}"
    )

    # Values not present in quotation remain blank.
    context["unit_count"] = technical.get("number_of_unit", "")
    context["load_kg"] = technical.get("load_kg", "")
    context["flooring"] = technical.get("car_flooring", "")
    context["representative_name"] = commercial.get(
        "representative_name", ""
    )
    context["emergency_light_yes_no"] = technical.get(
        "emergency_light_yes_no", ""
    )
    context["fireman_switch_yes_no"] = technical.get(
        "fireman_switch_yes_no", ""
    )

    document = DocxTemplate(BytesIO(template_bytes))
    document.render(context, autoescape=True)

    output = BytesIO()
    document.save(output)
    return output.getvalue()
