"""
Khidmat AI — Pricing Engine
Dynamic pricing based on service type, area, time, and urgency.
All prices in PKR. Uses real Karachi area multipliers.
"""
from typing import Optional


# ============================================================
# RATE TABLES
# ============================================================

BASE_RATES: dict[str, dict] = {
    "electrician":       {"min": 800,  "max": 2500, "peak_mult": 1.3},
    "plumber":           {"min": 600,  "max": 2000, "peak_mult": 1.4},
    "ac_technician":     {"min": 1200, "max": 3500, "peak_mult": 1.2},
    "ac_mechanic":       {"min": 1200, "max": 3500, "peak_mult": 1.2},  # alias for ac_technician
    "carpenter":         {"min": 1000, "max": 3000, "peak_mult": 1.1},
    "painter":           {"min": 800,  "max": 2500, "peak_mult": 1.0},
    "tutor":             {"min": 500,  "max": 2000, "peak_mult": 1.1},
    "beautician":        {"min": 800,  "max": 3000, "peak_mult": 1.2},
    "generator":         {"min": 1500, "max": 4000, "peak_mult": 1.5},
    "generator_mechanic":{"min": 1500, "max": 4000, "peak_mult": 1.5},  # alias for generator
    "welder":            {"min": 1000, "max": 3000, "peak_mult": 1.1},
    "tiler":             {"min": 1200, "max": 3500, "peak_mult": 1.1},
    # Additional services used in the Flutter app
    "house_maid":        {"min": 500,  "max": 1500, "peak_mult": 1.0},
    "maid":              {"min": 500,  "max": 1500, "peak_mult": 1.0},
    "gardener":          {"min": 600,  "max": 1800, "peak_mult": 1.0},
    "mali":              {"min": 600,  "max": 1800, "peak_mult": 1.0},
    "driver":            {"min": 700,  "max": 2000, "peak_mult": 1.1},
    "cook":              {"min": 800,  "max": 2500, "peak_mult": 1.0},
    "security_guard":    {"min": 700,  "max": 2000, "peak_mult": 1.0},
    "cleaner":           {"min": 500,  "max": 1500, "peak_mult": 1.0},
    "technician":        {"min": 800,  "max": 2500, "peak_mult": 1.2},
    "mechanic":          {"min": 1000, "max": 3000, "peak_mult": 1.2},
    "tailor":            {"min": 500,  "max": 2000, "peak_mult": 1.0},
    "barber":            {"min": 300,  "max": 1000, "peak_mult": 1.1},
    "nurse":             {"min": 1500, "max": 4000, "peak_mult": 1.0},
    "caretaker":         {"min": 1000, "max": 3000, "peak_mult": 1.0},
    "washer":            {"min": 500,  "max": 1500, "peak_mult": 1.0},
    "ironman":           {"min": 400,  "max": 1200, "peak_mult": 1.0},
}

AREA_MULTIPLIERS: dict[str, float] = {
    # ── Karachi ──────────────────────────────────────────
    "DHA Phase 5": 1.3,
    "DHA": 1.3,
    "Clifton Block 4": 1.3,
    "Clifton": 1.3,
    "PECHS Block 2": 1.15,
    "PECHS": 1.15,
    "Gulshan-e-Iqbal Block 13": 1.1,
    "Gulshan-e-Iqbal": 1.1,
    "Gulshan": 1.1,
    "North Nazimabad Block H": 1.0,
    "North Nazimabad": 1.0,
    "Nazimabad No. 3": 0.95,
    "Nazimabad": 0.95,
    "Korangi Industrial": 0.9,
    "Korangi": 0.9,
    "Orangi Town Sector 11": 0.85,
    "Orangi Town": 0.85,
    "Lyari Town": 0.85,
    "Lyari": 0.85,
    "Landhi Colony": 0.88,
    "Landhi": 0.88,
    "Malir Halt": 0.92,
    "Saddar Cantt": 1.05,
    "Saddar": 1.05,
    "Garden East": 1.0,
    "Baldia Town": 0.85,
    "Surjani Town Sector 7A": 0.88,
    "Shah Faisal Colony": 0.95,
    "Bufferzone Sector 15A": 0.95,
    "Federal B Area Block 4": 1.0,
    "Liaquatabad No. 10": 0.95,
    "Gulistan-e-Jauhar Block 14": 1.0,
    "Gulistan-e-Jauhar": 1.0,
    "Karachi": 1.0,
    # ── Lahore ───────────────────────────────────────────
    "DHA Lahore": 1.3,
    "DHA Phase 6": 1.3,
    "DHA Phase 5 Lahore": 1.25,
    "Gulberg": 1.25,
    "Gulberg III": 1.25,
    "Johar Town": 1.15,
    "Model Town": 1.2,
    "Bahria Town Lahore": 1.2,
    "Bahria Town": 1.2,
    "Wapda Town": 1.1,
    "Township": 1.0,
    "Faisal Town": 1.05,
    "Garden Town": 1.15,
    "Iqbal Town": 1.0,
    "Shadman": 1.1,
    "Cavalry Ground": 1.1,
    "Cantt": 1.15,
    "Cantonment": 1.15,
    "Samanabad": 0.95,
    "Hanjarwal": 0.85,
    "Data Ganj Bakhsh": 0.9,
    "Ravi Town": 0.88,
    "Shalimar": 0.9,
    "Lahore": 1.0,
    # ── Islamabad / Rawalpindi ────────────────────────────
    "F-6": 1.3,
    "F-7": 1.3,
    "F-8": 1.25,
    "F-10": 1.2,
    "F-11": 1.2,
    "G-9": 1.05,
    "G-10": 1.05,
    "G-11": 1.05,
    "G-13": 1.0,
    "I-8": 1.1,
    "I-10": 1.05,
    "Blue Area": 1.2,
    "Bahria Town Islamabad": 1.2,
    "DHA Islamabad": 1.25,
    "Islamabad": 1.1,
    "Rawalpindi": 1.0,
    "Satellite Town": 1.0,
    "Chaklala": 1.0,
    "Saddar Rawalpindi": 0.95,
    # ── Other Cities ─────────────────────────────────────
    "Peshawar": 0.9,
    "Quetta": 0.85,
    "Faisalabad": 0.95,
    "Multan": 0.9,
    "Hyderabad": 0.9,
    "Sialkot": 0.95,
    "Gujranwala": 0.9,
    "Abbottabad": 0.9,
}

URGENCY_MULTIPLIERS: dict[str, float] = {
    "emergency": 1.5,
    "urgent": 1.2,
    "normal": 1.0,
    "flexible": 0.9,
}


# ============================================================
# PRICING CALCULATION
# ============================================================

def calculate_fair_price(
    service_type: str,
    area: Optional[str],
    time: Optional[str],
    urgency: str = "normal",
) -> dict:
    """
    Calculate fair price range for a service.
    Returns min, max, breakdown string, and all multipliers applied.
    """
    base = BASE_RATES.get(service_type, {"min": 800, "max": 2000, "peak_mult": 1.0})

    # Area multiplier
    area_mult = 1.0
    if area:
        # Try exact match first, then partial match
        area_mult = AREA_MULTIPLIERS.get(area, 1.0)
        if area_mult == 1.0:
            for key, val in AREA_MULTIPLIERS.items():
                if key.lower() in area.lower() or area.lower() in key.lower():
                    area_mult = val
                    break

    # Urgency multiplier
    urgency_mult = URGENCY_MULTIPLIERS.get(urgency, 1.0)

    # Peak hours: 7-9am and 5-8pm
    peak_mult = 1.0
    is_peak = False
    if time:
        try:
            hour = int(time.split(":")[0])
            is_peak = (7 <= hour <= 9) or (17 <= hour <= 20)
            if is_peak:
                peak_mult = base["peak_mult"]
        except (ValueError, IndexError):
            pass

    # Calculate final range
    total_mult = area_mult * urgency_mult * peak_mult
    final_min = round(base["min"] * total_mult)
    final_max = round(base["max"] * total_mult)

    # Build breakdown string
    parts = [f"Base: Rs {base['min']}-{base['max']}"]
    if area_mult != 1.0:
        sign = "+" if area_mult > 1 else ""
        parts.append(f"Area ({area}): {sign}{round((area_mult - 1) * 100)}%")
    if is_peak:
        parts.append(f"Peak hours: +{round((base['peak_mult'] - 1) * 100)}%")
    if urgency_mult != 1.0:
        sign = "+" if urgency_mult > 1 else ""
        parts.append(f"Urgency ({urgency}): {sign}{round((urgency_mult - 1) * 100)}%")

    breakdown = " | ".join(parts)

    return {
        "min": final_min,
        "max": final_max,
        "breakdown": breakdown,
        "area_multiplier": area_mult,
        "urgency_multiplier": urgency_mult,
        "peak_multiplier": peak_mult,
        "is_peak": is_peak,
    }


def assess_price(quoted_price: int, fair_range: dict) -> dict:
    """Assess whether a quoted price is fair relative to the market range."""
    is_above = quoted_price > fair_range["max"]
    is_below = quoted_price < fair_range["min"]

    if is_above:
        assessment = "above_market"
        diff = quoted_price - fair_range["max"]
        message = (
            f"Provider ka rate Rs {quoted_price} hai, jo market se "
            f"Rs {diff} zyada hai. Counter-offer: Rs {fair_range['max']}?"
        )
        negotiation_needed = True
    elif is_below:
        assessment = "below_market"
        message = (
            f"Note: Rate Rs {quoted_price} market minimum se kam hai. "
            f"Quality verify karein."
        )
        negotiation_needed = False
    else:
        assessment = "fair"
        message = (
            f"Rs {quoted_price} fair rate hai "
            f"(market range: Rs {fair_range['min']}-{fair_range['max']})."
        )
        negotiation_needed = False

    return {
        "assessment": assessment,
        "negotiation_needed": negotiation_needed,
        "message": message,
        "message_ur": message,
        "quoted_price": quoted_price,
        "fair_min": fair_range["min"],
        "fair_max": fair_range["max"],
    }
