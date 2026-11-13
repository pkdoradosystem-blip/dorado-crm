import re

from PIL import Image as PILImage
from io import BytesIO as ImageBytesIO
from docx.shared import Mm as ImageMm


import json
from io import BytesIO
from docx.shared import Mm
from sqlalchemy import text
from decimal import Decimal, InvalidOperation
from docxtpl import DocxTemplate, InlineImage


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



# DORADO AUTO FIT IMAGE
def dorado_auto_fit_image(document, image_data, max_w, max_h):
    data = bytes(image_data)

    with PILImage.open(ImageBytesIO(data)) as img:
        width, height = img.size

    if width <= 0 or height <= 0:
        raise ValueError("Invalid image dimensions")

    scale = min(
        1.0,
        max_w / width,
        max_h / height,
    )

    return InlineImage(
        document,
        ImageBytesIO(data),
        width=ImageMm(width * scale),
        height=ImageMm(height * scale),
    )

def build_word_quotation(quotation, template_bytes, db=None):
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

    # Avoid duplicated words such as "Passenger Passenger Lift".
    lift_type_text = str(lift_type or "").strip()
    capacity_text = str(capacity or "").strip()
    floor_text = str(floor or "").strip()
    if lift_type_text.lower().startswith("passenger"):
        description = f"{capacity_text} {lift_type_text}".strip()
    else:
        description = f"{capacity_text} Passenger {lift_type_text}".strip()
    context["base_lift_description"] = (
        f"{description}, {floor_text}" if floor_text else description
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


    # DORADO FINAL MAPPING NORMALIZATION
    def first_value(*values):
        for value in values:
            if value is None or isinstance(value, bool):
                continue
            if isinstance(value, str) and not value.strip():
                continue
            if isinstance(value, (list, tuple)):
                if not value:
                    continue
                return ", ".join(str(x) for x in value if x is not None)
            return value
        return ""

    context["customer_address"] = first_value(
        quotation.office_address,
        quotation.site_address,
    )

    context["site_location"] = first_value(
        quotation.location,
        quotation.site_address,
    )

    context["unit_count"] = first_value(
        technical.get("number_of_unit"),
        technical.get("no_of_unit"),
        technical.get("unit_count"),
    )

    context["load_kg"] = first_value(
        technical.get("load_kg"),
        technical.get("rated_load"),
        technical.get("load"),
    )

    context["load"] = context["load_kg"]
    context["rated_load"] = context["load_kg"]

    context["wire_ropes"] = first_value(
        technical.get("wire_rope"),
        technical.get("wire_ropes"),
    )
    context["ropes"] = context["wire_ropes"]

    context["flooring"] = first_value(
        technical.get("car_flooring"),
        technical.get("flooring"),
    )

    context["delivery_weeks"] = first_value(
        commercial.get("delivery_weeks"),
        technical.get("delivery_weeks"),
    )

    context["installation_weeks"] = first_value(
        commercial.get("installation_weeks"),
        technical.get("installation_weeks"),
    )

    # Match all placeholders in the uploaded Dorado Modern template.
    # Only populate from real quotation data; never invent specifications.
    additional_fields = {
        "speed": ("speed", "lift_speed"),
        "overhead": ("overhead", "over_head"),
        "pit": ("pit", "pit_depth"),
        "power_supply": ("power_supply",),
        "machine_room_dimension": ("machine_room_dimension",),
        "installation_type": ("installation", "installation_type"),
        "base_door_type": ("landing_door_type", "base_door_type"),
        "base_cabin_finish": ("car_enclosure", "base_cabin_finish"),
        "emergency_light_yes_no": ("emergency_light_yes_no",),
        "fireman_switch_yes_no": ("fireman_switch_yes_no",),
    }
    for word_key, keys in additional_fields.items():
        if not context.get(word_key):
            context[word_key] = first_value(
                *(technical.get(k) for k in keys),
                *(commercial.get(k) for k in keys),
            )

    # Always define image placeholders, even when no image is selected.
    for image_key in (
        "main_lift_image", "landing_door_image",
        "controller_image", "machine_image",
    ):
        context[image_key] = ""

    # DORADO PLAIN TEMPLATE SUPPORT V1
    # Detect the selected legacy <<...>> template without altering its layout.
    def plain_paragraphs(doc):
        from docx.oxml.ns import qn
        from docx.text.paragraph import Paragraph
        for node in doc.element.body.iter(qn("w:p")):
            yield Paragraph(node, doc)
        for section in doc.sections:
            for part in (section.header, section.footer):
                for node in part._element.iter(qn("w:p")):
                    yield Paragraph(node, part)


    def plain_replace(paragraph, values):
        """Replace only placeholder characters in existing w:t nodes.

        Do not assign run.text or paragraph.text: those setters rebuild XML
        and can remove run-level markup. All paragraph/table/page formatting,
        run properties, tabs, breaks, and drawings are retained.
        """
        from docx.oxml.ns import qn

        # Word may split one <<placeholder>> across multiple text nodes.
        # Work with those nodes directly, preserving all surrounding XML.
        nodes = list(paragraph._p.iter(qn("w:t")))
        if not nodes:
            return
        whole = "".join(node.text or "" for node in nodes)
        if "<<" not in whole:
            return

        pattern = re.compile(r"DRDS/<<ID>>|<<([^<>]+)>>")
        for match in reversed(list(pattern.finditer(whole))):
            if match.group(0) == "DRDS/<<ID>>":
                value = values.get("__legacy_offer__")
            else:
                value = values.get(match.group(1).strip())
            if value is None:
                continue
            value = str(value)

            cursor = 0
            spans = []
            for node in nodes:
                original = node.text or ""
                end = cursor + len(original)
                if cursor < match.end() and end > match.start():
                    spans.append((node, max(0, match.start() - cursor),
                                  min(len(original), match.end() - cursor)))
                cursor = end
            if not spans:
                continue
            for i, (node, start, end) in enumerate(spans):
                original = node.text or ""
                node.text = (original[:start] + (value if i == 0 else "")
                             + original[end:])
                # Word needs xml:space=preserve for meaningful edge spaces.
                if node.text and (node.text[0].isspace() or node.text[-1].isspace()):
                    node.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")

    from docx import Document
    source_doc = Document(BytesIO(template_bytes))

    is_plain_template = any(
        "<<" in p.text and ">>" in p.text
        for p in plain_paragraphs(source_doc)
    )

    # Template display LOAD: persons x 68 kg, as requested.
    # This is a quotation display calculation, not a certified rated load.
    person_raw = str(technical.get("person_capacity") or "").strip()
    person_match = re.match(r"^(\d+(?:\.\d+)?)\s*(?:persons?|passengers?)?\s*$", person_raw, re.I)
    calculated_load = ""
    if person_match:
        count = Decimal(person_match.group(1))
        calculated_load = f"{count * Decimal(68):g}"

    plain_fields = {
        "Name": context.get("customer_name", ""),
        "Address": context.get("customer_address", ""),
        "Pin": first_value(commercial.get("pin"), commercial.get("pincode"), technical.get("pin")),
        "Contact": context.get("mobile", ""),
        "Email": first_value(commercial.get("email"), technical.get("email")),
        "quotation_no": context.get("quotation_no", ""),
        "Date": context.get("quotation_date", ""),
        "Marketing By (Name)": context.get("representative_name", ""),
        "Floor": technical.get("number_of_floor", context.get("floor_rise", "")),
        "Person": re.sub(r"(?i)\s*(persons?|passengers?)\s*$", "", str(technical.get("person_capacity") or "")).strip(),
        "Lifttype": context.get("lift_type", ""),
        "Site": context.get("site_location", ""),
        "Load": calculated_load or technical.get("rated_load") or technical.get("load") or "",
        "FLHeight": re.sub(r"(?i)\s*(?:meters?|m)\s*$", "", str(first_value(technical.get("total_height"), technical.get("floor_height")))).strip(),
        "NoOpening": technical.get("no_of_opening", context.get("no_of_openings", "")),
        "NoStop": context.get("no_of_stops", ""),
        "Landoor": technical.get("landing_door_type", ""),
        "CarEncloser": technical.get("car_enclosure", ""),
        "cardoor": technical.get("car_door_type", ""),
        "opening": re.sub(r"(?i)\s*mm\s*$", "", str(technical.get("entrance_opening") or "")).strip(),
        "ShaftW": re.sub(r"(?i)\s*mm\s*$", "", str(technical.get("shaft_width") or "")).strip(),
        "ShaftD": re.sub(r"(?i)\s*mm\s*$", "", str(technical.get("shaft_depth") or "")).strip(),
        "Door Operation": technical.get("door_operation", ""),
        "Overhead": re.sub(r"(?i)\s*mm\s*$", "", str(first_value(technical.get("overhead"), technical.get("over_head")))).strip(),
        "Ard": first_value(technical.get("ard_required"), commercial.get("ard_selected")),
        # Fields present in the final uploaded Word template.
        "drive_make": first_value(technical.get("drive_make"), technical.get("vvvf_drive_make"), technical.get("vvvf_make"), commercial.get("drive_make")),
        "speed": first_value(technical.get("speed"), technical.get("lift_speed")),
        "gear_motor_machine": first_value(technical.get("gear_motor_machine"), technical.get("machine_make")),
        # Machine manufacturer is separate from machine type (e.g. Geared).
        "machine_make": first_value(
            technical.get("machine_make"),
            technical.get("gear_motor_machine_make"),
            technical.get("motor_make"),
            commercial.get("machine_make"),
            commercial.get("gear_motor_machine_make"),
            commercial.get("motor_make"),
        ),
        "installation": first_value(technical.get("installation"), technical.get("installation_type")),
        "price": context.get("final_price_including_gst", ""),
        "Cabine Model No.": context.get("cabin_model_no", ""),
        "License": re.sub(r"\.00$", "", str(context.get("license_fee") or "")).strip(),
        "Validity": re.sub(r"(?i)\s*days?\s*$", "", str(context.get("quotation_validity") or "")).strip(),
    }
    # The original template used <<ID>> after a fixed old prefix.
    # Replace that entire legacy prefix only when present.
    plain_fields["__legacy_offer__"] = context.get("quotation_no", "")

    # DORADO WORD IMAGE INTEGRATION
    if db is not None and not is_plain_template:
        rows = db.execute(
            text("""
                SELECT qi.category, li.image_data
                FROM quotation_images qi
                JOIN lift_images li ON li.id = qi.image_id
                WHERE qi.quotation_id = :qid
                ORDER BY qi.display_order, qi.id
            """),
            {"qid": quotation.id},
        ).mappings().all()

        image_fields = {
            "MAIN_LIFT": ("main_lift_image", 80, 100),
            "GATE": ("landing_door_image", 45, 55),
            "CONTROLLER": ("controller_image", 45, 55),
            "MACHINE": ("machine_image", 45, 55),
        }

        for row in rows:
            category = row["category"]
            if category not in image_fields:
                continue

            field, max_w, max_h = image_fields[category]
            if row["image_data"] is not None:
                context[field] = dorado_auto_fit_image(
                    document,
                    row["image_data"],
                    max_w,
                    max_h,
                )

    if is_plain_template:
        filled = source_doc
        for paragraph in plain_paragraphs(filled):
            plain_replace(paragraph, plain_fields)
    else:
        document.render(context, autoescape=True)


    output = BytesIO()
    if is_plain_template:
        from zipfile import ZipFile
        from lxml import etree
        from docx.oxml.ns import qn

        def replace_xml_only(xml_bytes):
            root = etree.fromstring(xml_bytes)
            pattern = re.compile(r"DRDS/<<ID>>|<<([^<>]+)>>")

            for paragraph in root.iter(qn("w:p")):
                nodes = list(paragraph.iter(qn("w:t")))
                whole = "".join(node.text or "" for node in nodes)

                for match in reversed(list(pattern.finditer(whole))):
                    if match.group(0) == "DRDS/<<ID>>":
                        value = plain_fields.get("__legacy_offer__")
                    else:
                        value = plain_fields.get(match.group(1).strip())

                    if value is None:
                        continue

                    cursor = 0
                    spans = []

                    for node in nodes:
                        original_text = node.text or ""
                        end = cursor + len(original_text)
                        if cursor < match.end() and end > match.start():
                            spans.append((
                                node,
                                max(0, match.start() - cursor),
                                min(len(original_text), match.end() - cursor),
                            ))
                        cursor = end

                    for i, (node, start, end) in enumerate(spans):
                        original_text = node.text or ""
                        node.text = (
                            original_text[:start]
                            + (str(value) if i == 0 else "")
                            + original_text[end:]
                        )
                        if node.text and (
                            node.text[0].isspace() or node.text[-1].isspace()
                        ):
                            node.set(
                                "{http://www.w3.org/XML/1998/namespace}space",
                                "preserve",
                            )

            return etree.tostring(
                root, encoding="UTF-8", xml_declaration=True
            )

        with ZipFile(BytesIO(template_bytes), "r") as original_zip:
            with ZipFile(output, "w") as output_zip:
                for info in original_zip.infolist():
                    part = original_zip.read(info.filename)
                    if (
                        info.filename == "word/document.xml"
                        or re.fullmatch(
                            r"word/(header|footer)\\d+\\.xml",
                            info.filename,
                        )
                    ):
                        part = replace_xml_only(part)
                    output_zip.writestr(info, part)
    else:
        document.save(output)
    return output.getvalue()
