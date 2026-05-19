import asyncio
import json
from agents.coordinator import orchestrate_booking

async def main():
    print("--- Testing safety mode = True ---")
    res1 = await orchestrate_booking(
        user_input="Ghar mein short circuit ho gaya hai, urgent electrician chahiye.",
        user_lat=24.8607,
        user_lng=67.0099,
        input_type="text",
        womens_safety_mode=True
    )
    print(f"Success: {res1.get('success')}")
    if not res1.get("success"):
        print(f"Error: {res1.get('error')}")
    else:
        print(f"Top Providers count: {len(res1.get('top_providers', []))}")
        for p in res1.get('top_providers', []):
            print(f"- {p['name']} ({p['distance_km']:.2f} km)")

    print("\n--- Testing safety mode = False ---")
    res2 = await orchestrate_booking(
        user_input="Ghar mein short circuit ho gaya hai, urgent electrician chahiye.",
        user_lat=24.8607,
        user_lng=67.0099,
        input_type="text",
        womens_safety_mode=False
    )
    print(f"Success: {res2.get('success')}")
    if not res2.get("success"):
        print(f"Error: {res2.get('error')}")
    else:
        print(f"Top Providers count: {len(res2.get('top_providers', []))}")
        for p in res2.get('top_providers', []):
            print(f"- {p['name']} ({p['distance_km']:.2f} km)")

if __name__ == "__main__":
    asyncio.run(main())
