import re
import json

prompt = """
You are the Khidmat Copilot, a highly sophisticated AI marketplace orchestrator and dashboard assistant for the Khidmat AI marketplace in Pakistan.

Your absolute priority is to answer the administrator's queries precisely and accurately using ONLY the live, real-time marketplace data provided below.

=== LIVE DASHBOARD DATA CONTEXT ===
1. Aggregate Statistics:
   - Total Bookings: 7
   - Active Providers: 5
   - Gross Merchandise Value (GMV): PKR 8,800
   - Successful/Confirmed Bookings Count: 3

2. Active Providers Registry (Earnings & Performance):
[
  {
    "rank": 1,
    "id": "0080eeac-f246-41ff-aade-655b42c02917",
    "name": "Muhammad Ali",
    "specialty": "electrician",
    "rating": 4.8,
    "jobs_completed": 5,
    "total_income_pkr": 4000.0,
    "is_available": true,
    "location": "G-10, Islamabad"
  },
  {
    "rank": 2,
    "id": "28b2444b-a273-428f-be2a-efd1310e6b14",
    "name": "Baqir Raza",
    "specialty": "electrician",
    "rating": 5.0,
    "jobs_completed": 0,
    "total_income_pkr": 0,
    "is_available": true,
    "location": "G-13, Islamabad"
  }
]

3. Bookings Ledger:
[]

4. Recent Agent Reasoning Traces:
[]

=== STRICT ADMINISTRATIVE GUARDRAILS ===
1. Respond using ONLY the facts, numbers, ratings, earnings, and locations present in the provided context.

Administrator: mujhe ye batao sab se kam income kis ki hai
"""

prompt_lower = prompt.lower()
prompt_lines = [line.strip() for line in prompt.split("\n") if line.strip()]
last_line = prompt_lines[-1].lower() if prompt_lines else prompt_lower
print("last_line:", last_line)

providers_match = re.search(r'2\. Active Providers Registry \(Earnings & Performance\):\s*(\[.*?\])', prompt, re.DOTALL)
if providers_match:
    print("Matched providers text:")
    print(providers_match.group(1))
    try:
        providers_list = json.loads(providers_match.group(1))
        print("Successfully parsed! Providers count:", len(providers_list))
    except Exception as e:
        print("Failed to parse providers:", e)
else:
    print("Providers did not match regex!")
