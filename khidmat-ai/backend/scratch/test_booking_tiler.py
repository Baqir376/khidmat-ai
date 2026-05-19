import asyncio
import json
from agents.coordinator import orchestrate_booking

async def main():
    result = await orchestrate_booking(
        user_input="I need a tiler in Karachi to fix my bathroom tiles",
        user_lat=24.8607,
        user_lng=67.0099,
        input_type="text",
        womens_safety_mode=False
    )
    print("--- PIPELINE RESULT ---")
    print(json.dumps(result, indent=2))

asyncio.run(main())
