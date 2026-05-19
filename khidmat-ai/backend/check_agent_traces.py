import asyncio
from services.firebase_service import query_collection

async def main():
    traces = await query_collection("agentTraces", order_by="-created_at", limit=10)
    print(f"Total traces found: {len(traces)}")
    for i, t in enumerate(traces):
        print(f"\nTrace {i+1}:")
        print(f"  Agent Name: {t.get('agent_name')}")
        print(f"  Step: {t.get('step_number')}")
        print(f"  Status: {t.get('status')}")
        print(f"  Input Data: {t.get('input_data')}")
        print(f"  Output Data: {t.get('output_data')}")
        print(f"  Reasoning Text: {t.get('reasoning_text')}")
        print(f"  Created At: {t.get('created_at')}")

if __name__ == '__main__':
    asyncio.run(main())
