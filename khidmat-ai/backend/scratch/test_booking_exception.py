import asyncio
import traceback
from agents.coordinator import orchestrate_booking

async def main():
    try:
        result = await orchestrate_booking(
            user_input="I need a tiler in Karachi to fix my bathroom tiles",
            user_lat=24.8607,
            user_lng=67.0099,
            input_type="text",
            womens_safety_mode=False
        )
        print("Success! Result:")
        print(result)
    except Exception as e:
        print("EXCEPTION OCCURRED:")
        traceback.print_exc()

asyncio.run(main())
