import re

prompt = """You are the IntentAgent for Khidmat AI, a service marketplace in Pakistan.
Your job is to extract structured information from user messages in Roman Urdu, Urdu, English, or Sindhi.

Extract these fields:
1. service_type: One of [plumber, electrician, ac_mechanic, house_maid, carpenter, painter, gardener, tutor, beautician, generator, welder, tiler]
...
User Input: "Ghar mein short circuit ho gaya hai, urgent electrician chahiye."
Input Type: text
"""

prompt_lower = prompt.lower()
user_input_match = re.search(r'user input:\s*"(.*?)"', prompt_lower)
if user_input_match:
    search_text = user_input_match.group(1)
    print(f"Extracted search_text: {search_text}")
else:
    search_text = prompt_lower
    print("Match failed!")
