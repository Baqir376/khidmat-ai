import asyncio
from agents.intent_agent import run_intent_agent

async def main():
    print("Testing intent agent...")
    res = await run_intent_agent(
        "Ghar ke tiles lagwane / floor marble installation ke liye tiler chahiye.",
        "test_session"
    )
    print(f"Success: {res.get('success')}")
    print(f"Intent: {res.get('intent')}")
    if not res.get("success"):
        print(f"Error: {res.get('error')}")

if __name__ == "__main__":
    asyncio.run(main())
