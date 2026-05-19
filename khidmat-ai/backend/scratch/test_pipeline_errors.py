import asyncio
import sys
sys.path.append('.')

from agents.coordinator import orchestrate_booking

async def main():
    print("Testing orchestrate_booking at Lahore (coordinates where no providers exist)...")
    res = await orchestrate_booking(
        user_input="need an electrician now",
        user_lat=31.5204,
        user_lng=74.3587,
        input_type="text",
        womens_safety_mode=False
    )
    
    print("\n--- Pipeline Result ---")
    print("Success:", res.get("success"))
    print("Error:", res.get("error"))
    print("Pipeline Status:", res.get("pipeline_status"))
    
    expected_error = "Service unavailable. We are sorry but no provider is giving service in this area"
    if res.get("error") == expected_error:
        print("\n[SUCCESS] The coordinator successfully returned the exact friendly error message!")
    else:
        print("\n[FAILURE] Expected error:", repr(expected_error))
        print("Got:", repr(res.get("error")))

if __name__ == "__main__":
    asyncio.run(main())
