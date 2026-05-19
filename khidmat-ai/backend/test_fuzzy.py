import re

def _fuzzy_match_service(user_input: str, raw_type: str) -> str:
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
                print(f"Matched {stype} because of keyword: '{kw}' with pattern '{pattern}'")
                return stype
    return "electrician"

user_input = "Ghar ke tiles lagwane / floor marble installation ke liye tiler chahiye near Karachi."
print("Matching user input with raw_type='tiling':")
res = _fuzzy_match_service(user_input, "tiling")
print(f"Result: {res}")

