
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

    document = DocxTemplate(BytesIO(template_bytes))
    document.render(context, autoescape=True)

    output = BytesIO()
    document.save(output)
    return output.getvalue()
