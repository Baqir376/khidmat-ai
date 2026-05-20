import asyncio
import json
from agents.negotiation_agent import run_negotiation_agent
from services.pricing_service import calculate_fair_price

async def main():
    # Simulate a tutor provider with hourly rate 5000 in Islamabad (G-13, G-10, or general)
    provider = {
        "id": "test-provider-id",
        "name_en": "inam rasool",
        "pricing_type": "hourly",
        "hourly_rate": 5000,
        "rate": 5000,
        "service_type_id": "tutor",
        "area_name": "G-13, Islamabad"
    }

    intent = {
        "service_type": "tutor",
        "location": "G-13, Islamabad",
        "urgency": "normal",
        "date": "today",
        "time": "now"
    }

    # In Phase 1 matching agent calculates the fair price:
    fair_price = calculate_fair_price("tutor", "G-13, Islamabad", None, "normal")
    print(f"Calculated Fair Price range: {fair_price}")

    # Now run negotiation agent (Phase 2 confirmation)
    res = await run_negotiation_agent(
        provider=provider,
        intent=intent,
        fair_price=fair_price,
        session_id="test-session-id"
    )

    print("\nNegotiation Agent Response:")
    print(json.dumps(res, indent=2))

if __name__ == "__main__":
    asyncio.run(main())
