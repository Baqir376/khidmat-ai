import asyncio
import json
from agents.coordinator import orchestrate_booking

async def main():
    print("Orchestrating booking...")
    res = await orchestrate_booking(
        user_input="Ghar mein short circuit ho gaya hai, urgent electrician chahiye.",
        user_lat=33.6512,
        user_lng=72.9876,
        input_type="text",
        womens_safety_mode=False
    )
    print(f"Success: {res.get('success')}")
    if not res.get("success"):
        print(f"Error: {res.get('error')}")
        print(f"Details: {res.get('details')}")
    else:
        print(f"Top Providers count: {len(res.get('top_providers', []))}")
        # Safe printing with ASCII fallback for Windows console
        print(json.dumps(res.get('top_providers'), indent=2, ensure_ascii=True))

if __name__ == "__main__":
    asyncio.run(main())
