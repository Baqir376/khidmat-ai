"""
Khidmat AI — Agent 1: Intent Agent
Extracts service type, location, date/time, and urgency from natural language.
Supports Roman Urdu, Urdu, English, and Sindhi.
"""
import time
import uuid
import re
from datetime import datetime, timedelta
from services.gemini_service import generate_json
from services.firebase_service import save_agent_trace

AGENT_NAME = "IntentAgent"

SYSTEM_INSTRUCTION = """You are the IntentAgent for Khidmat AI, a service marketplace in Pakistan.
Your job is to extract structured information from user messages in Roman Urdu, Urdu, English, or Sindhi.

Extract these fields:
1. service_type: One of [plumber, electrician, ac_mechanic, house_maid, carpenter, painter, gardener, tutor, beautician, generator, welder, tiler]
2. location: Area name (e.g., "Gulshan-e-Iqbal", "DHA Phase 5", "G-10")
3. date: Specific date or relative (today, tomorrow, kal, parson)
4. time: Time of day (subah=morning=9AM, dopehar=afternoon=2PM, shaam=evening=6PM, abhi=now)
5. urgency: One of [emergency, urgent, normal, flexible]
6. language: Detected language [en, ur, roman_ur, sd]
7. additional_details: Any extra info (problem description, preferences)

Common Roman Urdu mappings:
- "bijli wala" / "electrician wala" = electrician
- "plumber" / "nalka wala" = plumber
- "AC wala" / "AC mechanic" / "AC technician" = ac_mechanic
- "badhai" / "carpenter" = carpenter
- "painter" / "rang wala" = painter
- "maid" / "ghar ki kaam wali" / "safai" = house_maid
- "mali" / "gardener" = gardener
- "teacher" / "tutor" / "sir/madam chahiye" = tutor
- "beautician" / "makeup wali" = beautician
- "generator wala" = generator
- "welder" / "loha wala" = welder
- "tiler" / "tile wala" / "mason" = tiler

Time mappings:
- "kal" = tomorrow, "parson" = day after tomorrow
- "subah" = 9:00, "dopehar" = 14:00, "shaam" = 18:00
- "abhi" / "fori" = now (emergency)

Respond ONLY with valid JSON."""


async def run_intent_agent(
    user_input: str,
    session_id: str,
    input_type: str = "text",
    image_base64: str = None,
) -> dict:
    """
    Extract structured intent from natural language input.
    Returns parsed intent with service type, location, time, and urgency.
    """
    start_time = time.time()
    trace_id = str(uuid.uuid4())[:12]

    try:
        image_context = "User attached a photo of the appliance issue." if image_base64 else ""

        prompt = f"""Parse this service request and extract structured data:

User Input: "{user_input}"
Input Type: {input_type}
{image_context}

Return JSON with: service_type, location, date, time, urgency, language, additional_details, confidence (0-1)"""

        result = await generate_json(prompt, SYSTEM_INSTRUCTION)

        # Post-process and validate
        service_type = result.get("service_type", "")
        valid_types = [
            "plumber", "electrician", "ac_mechanic", "house_maid",
            "carpenter", "painter", "gardener", "tutor",
            "beautician", "generator", "welder", "tiler"
        ]

        if service_type not in valid_types:
            # Fuzzy match
            service_type = _fuzzy_match_service(user_input, service_type)
            result["service_type"] = service_type
            result["service_type_corrected"] = True

        # Check for explicit Date and Time in the user prompt (e.g. injected by UI)
        explicit_date = None
        explicit_time = None
        
        # Match 'Date: DD/MM/YYYY' or 'Date: DD-MM-YYYY' or similar
        date_match = re.search(r'(?:Date|date):\s*([^\n\r]+)', user_input)
        if date_match:
            explicit_date = date_match.group(1).strip()
            
        # Match 'Time: HH:MM AM/PM' or 'Time: HH:MM' or similar
        time_match = re.search(r'(?:Time|time):\s*([^\n\r]+)', user_input)
        if time_match:
            explicit_time = time_match.group(1).strip()

        # Resolve relative dates
        date_str = explicit_date or result.get("date") or "today"
        resolved_date = _resolve_date(date_str)
        result["resolved_date"] = resolved_date

        # Resolve time
        time_str = explicit_time or result.get("time") or "morning"
        resolved_time = _resolve_time(time_str)
        result["resolved_time"] = resolved_time

        # Save original input text
        result["original_text"] = user_input

        # Set urgency if "abhi" or "fori" detected
        if any(word in user_input.lower() for word in ["abhi", "fori", "emergency", "jaldi"]):
            result["urgency"] = "urgent"

        duration_ms = int((time.time() - start_time) * 1000)

        # Build reasoning
        reasoning = (
            f"Detected service: {result.get('service_type')} | "
            f"Location: {result.get('location', 'not specified')} | "
            f"Date: {resolved_date} | Time: {resolved_time} | "
            f"Language: {result.get('language', 'en')} | "
            f"Urgency: {result.get('urgency', 'normal')} | "
            f"Confidence: {result.get('confidence', 0.8)}"
        )

        # Save trace
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 1,
            "input_data": {"user_input": user_input, "input_type": input_type},
            "output_data": result,
            "tool_calls": [{"tool": "gemini_generate_json", "status": "success"}],
            "reasoning_text": reasoning,
            "duration_ms": duration_ms,
            "status": "success",
        }
        await save_agent_trace(trace)

        return {
            "success": True,
            "intent": result,
            "trace": trace,
        }

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        trace = {
            "id": trace_id,
            "session_id": session_id,
            "agent_name": AGENT_NAME,
            "step_number": 1,
            "input_data": {"user_input": user_input},
            "output_data": {"error": str(e)},
            "reasoning_text": f"Intent extraction failed: {e}",
            "duration_ms": duration_ms,
            "status": "error",
        }
        await save_agent_trace(trace)
        return {"success": False, "error": str(e), "trace": trace}


def _fuzzy_match_service(user_input: str, raw_type: str) -> str:
    """Fuzzy match service type from user input keywords with proper word boundaries."""
    import re
    text = (user_input + " " + raw_type).lower()
    mappings = {
        "electrician": ["bijli", "electric", "wiring", "switch", "fan"],
        "plumber": ["plumb", "nalka", "pipe", "drain", "nala", "pani"],
        "ac_mechanic": ["ac", "air condition", "cooling", "thanda", "mechanic"],
        "carpenter": ["badhai", "carpenter", "wood", "furniture", "almari"],
        "painter": ["paint", "rang", "wall", "colour"],
        "house_maid": ["maid", "safai", "cleaning", "kaam wali", "dhona", "sweeper", "dusting"],
        "gardener": ["gardener", "mali", "lawn", "plant", "pauda", "ghas", "grass"],
        "tutor": ["tutor", "teacher", "tuition", "padhai", "sir", "madam", "math", "english", "science"],
        "beautician": ["beauty", "makeup", "parlour", "mehnd", "facial"],
        "generator": ["generator", "genset"],
        "welder": ["welder", "welding", "loha", "iron", "sariya"],
        "tiler": ["tiler", "tile", "marble", "mason", "pathar", "mistri", "cement", "floor"],
    }
    for stype, keywords in mappings.items():
        for kw in keywords:
            pattern = rf"\b{re.escape(kw)}\b" if kw.isalnum() else re.escape(kw)
            if re.search(pattern, text):
                return stype
    return "electrician"  # Safe default



def _resolve_date(date_val) -> str:
    """Resolve exact or relative date strings/dicts to actual ISO dates YYYY-MM-DD."""
    today = datetime.now()
    
    # If date_val is a dict, extract values from it
    if isinstance(date_val, dict):
        day = date_val.get("day") or date_val.get("date") or date_val.get("DD")
        month = date_val.get("month") or date_val.get("MM")
        year = date_val.get("year") or date_val.get("YYYY")
        
        if not day and "date" in date_val:
            date_val = date_val["date"]
        elif day and month:
            try:
                y = int(year) if year else today.year
                m = int(month)
                d = int(day)
                return f"{y:04d}-{m:02d}-{d:02d}"
            except Exception:
                pass

    # Convert to string and handle potential JSON
    date_str = str(date_val) if date_val is not None else "today"
    date_str_strip = date_str.strip()
    if date_str_strip.startswith("{") and date_str_strip.endswith("}"):
        import json
        try:
            parsed = json.loads(date_str_strip.replace("'", '"'))
            if isinstance(parsed, dict):
                return _resolve_date(parsed)
        except Exception:
            pass

    # 1. Match explicit DD/MM/YYYY or DD-MM-YYYY
    match_slash = re.search(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})', date_str)
    if match_slash:
        try:
            day = int(match_slash.group(1))
            month = int(match_slash.group(2))
            year = int(match_slash.group(3))
            return f"{year:04d}-{month:02d}-{day:02d}"
        except Exception:
            pass
            
    # 2. Match standard ISO YYYY-MM-DD or YYYY/MM/DD
    match_iso = re.search(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})', date_str)
    if match_iso:
        try:
            year = int(match_iso.group(1))
            month = int(match_iso.group(2))
            day = int(match_iso.group(3))
            return f"{year:04d}-{month:02d}-{day:02d}"
        except Exception:
            pass

    # 3. Match DD/MM or DD-MM and assume current year
    match_short = re.search(r'\b(\d{1,2})[/-](\d{1,2})\b', date_str)
    if match_short:
        try:
            day = int(match_short.group(1))
            month = int(match_short.group(2))
            year = today.year
            return f"{year:04d}-{month:02d}-{day:02d}"
        except Exception:
            pass

    # 4. Fallback to relative mapping
    mapping = {
        "today": today,
        "aaj": today,
        "tomorrow": today + timedelta(days=1),
        "kal": today + timedelta(days=1),
        "parson": today + timedelta(days=2),
        "day after tomorrow": today + timedelta(days=2),
    }
    date_lower = date_str.lower().strip()
    resolved = mapping.get(date_lower, today + timedelta(days=1))
    return resolved.strftime("%Y-%m-%d")


def _resolve_time(time_val) -> str:
    """Resolve time descriptions, dicts, or formatting to standard 12h/24h or relative format."""
    # If time_val is a dict, extract values from it
    if isinstance(time_val, dict):
        hour = time_val.get("hour") or time_val.get("HH")
        minute = time_val.get("minute") or time_val.get("MM") or 0
        period = time_val.get("period") or time_val.get("ampm") or ""
        
        if hour is not None:
            try:
                h = int(hour)
                m = int(minute)
                p = str(period).lower().strip()
                if p == "pm" and h < 12:
                    h += 12
                elif p == "am" and h == 12:
                    h = 0
                return f"{h:02d}:{m:02d}"
            except Exception:
                pass
                
    time_str = str(time_val) if time_val is not None else "morning"
    time_str_strip = time_str.strip()
    
    # Handle potential JSON string
    if time_str_strip.startswith("{") and time_str_strip.endswith("}"):
        import json
        try:
            parsed = json.loads(time_str_strip.replace("'", '"'))
            if isinstance(parsed, dict):
                return _resolve_time(parsed)
        except Exception:
            pass

    # Match time with AM/PM (e.g., 10:00 PM or 10 PM)
    match_ampm = re.search(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)', time_str)
    if match_ampm:
        try:
            hour = int(match_ampm.group(1))
            minute = int(match_ampm.group(2)) if match_ampm.group(2) else 0
            period = match_ampm.group(3).lower()
            # We want to return a standard clean representation, keeping the period or 24h
            # Return standard 24h format for database storage consistency: "HH:MM"
            if period == 'pm' and hour < 12:
                hour += 12
            elif period == 'am' and hour == 12:
                hour = 0
            return f"{hour:02d}:{minute:02d}"
        except Exception:
            pass

    # Match time in 24h format (e.g., 22:00 or 10:00)
    match_24h = re.search(r'(\d{1,2}):(\d{2})', time_str)
    if match_24h:
        try:
            hour = int(match_24h.group(1))
            minute = int(match_24h.group(2))
            return f"{hour:02d}:{minute:02d}"
        except Exception:
            pass

    mapping = {
        "morning": "09:00",
        "subah": "09:00",
        "dopehar": "14:00",
        "afternoon": "14:00",
        "shaam": "18:00",
        "evening": "18:00",
        "raat": "20:00",
        "night": "20:00",
        "now": "ASAP",
        "abhi": "ASAP",
        "fori": "ASAP",
    }
    time_lower = time_str.lower().strip()
    if time_lower in mapping:
        return mapping[time_lower]
    return time_str
