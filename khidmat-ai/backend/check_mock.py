import re
import json

def test_mock(prompt):
    prompt_lower = prompt.lower()
    print(f"Prompt: {prompt_lower}")
    
    service_keywords = {
        "plumber": ["plumber", "nalka", "pipe", "drain", "nala", "pani", "plumb"],
        "electrician": ["bijli", "electric", "wiring", "switch", "fan", "light", "socket"],
        "ac_mechanic": ["ac", "air condition", "cooling", "thanda", "ac wala"],
        "carpenter": ["badhai", "carpenter", "wood", "furniture", "almari", "door"],
        "painter": ["paint", "rang", "wall", "colour", "rangan"],
        "tutor": ["tutor", "teacher", "tuition", "padhai", "sir", "madam", "study"],
        "beautician": ["beauty", "makeup", "parlour", "mehnd", "facial", "hair"],
        "generator": ["generator", "genset"],
        "welder": ["weld", "loha", "iron", "gate"],
        "tiler": ["tile", "tiler", "marble", "floor"],
    }
    
    for stype, keywords in service_keywords.items():
        for kw in keywords:
            pattern = rf"\b{re.escape(kw)}\b" if kw.isalnum() else re.escape(kw)
            match = re.search(pattern, prompt_lower)
            if match:
                print(f"Matched service: {stype} via keyword: '{kw}' (pattern: '{pattern}')")
                return stype
    return "none"

user_input = "Ghar ke tiles lagwane / floor marble installation ke liye tiler chahiye.\nDate: 27/5/2026\nTime: 4:11 PM"
prompt = f"""Parse this service request and extract structured data:

User Input: "{user_input}"
Input Type: text

Return JSON with: service_type, location, date, time, urgency, language, additional_details, confidence (0-1)

IMPORTANT: Respond ONLY with valid JSON. No markdown, no explanation."""

test_mock(prompt)
