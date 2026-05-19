import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
from services.gemini_service import _mock_response

# Simulate the prompt generated in admin_routes.py
providers_ctx = [
  {
    "rank": 1,
    "id": "0080eeac-f246-41ff-aade-655b42c02917",
    "name": "Muhammad Ali",
    "specialty": "electrician",
    "rating": 4.8,
    "jobs_completed": 5,
    "total_income_pkr": 4000.0,
    "is_available": True,
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
    "is_available": True,
    "location": "G-13, Islamabad"
  }
]

bookings_ctx = []
traces_ctx = []

system_instruction = f"""You are the Khidmat Copilot, a highly sophisticated AI marketplace orchestrator and dashboard assistant for the Khidmat AI marketplace in Pakistan.

Your absolute priority is to answer the administrator's queries precisely and accurately using ONLY the live, real-time marketplace data provided below.

=== LIVE DASHBOARD DATA CONTEXT ===
1. Aggregate Statistics:
   - Total Bookings: 7
   - Active Providers: 5
   - Gross Merchandise Value (GMV): PKR 8,800
   - Successful/Confirmed Bookings Count: 3

2. Active Providers Registry (Earnings & Performance):
{json.dumps(providers_ctx, indent=2)}

3. Bookings Ledger:
{json.dumps(bookings_ctx, indent=2)}

4. Recent Agent Reasoning Traces:
{json.dumps(traces_ctx, indent=2)}
"""

history = [
  {"role": "ai", "text": "Assalam-o-Alaikum Administrator. I am the Khidmat Copilot, connected directly to your live database. Ask me any queries about bookings, active provider earnings, or agent reasoning traces."},
  {"role": "user", "text": "mujhe ye batao sab se kam income kis ki hai"}
]

prompt_parts = []
for h in history:
    role = "Administrator" if h.get("role") == "user" else "Copilot"
    prompt_parts.append(f"{role}: {h.get('text')}")
prompt_parts.append(f"Administrator: mujhe ye batao sab se kam income kis ki hai")
prompt = "\n".join(prompt_parts)

full_prompt = f"{system_instruction}\n\n{prompt}"

print("Calling _mock_response...")
res = _mock_response(full_prompt)
print("Response:")
print(repr(res))
