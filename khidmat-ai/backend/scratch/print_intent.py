import asyncio
from agents.intent_agent import run_intent_agent

async def main():
    result = await run_intent_agent(
        user_input="I need a tiler in Karachi to fix my bathroom tiles",
        session_id="test_session"
    )
    import json
    print(json.dumps(result, indent=2))

asyncio.run(main())
