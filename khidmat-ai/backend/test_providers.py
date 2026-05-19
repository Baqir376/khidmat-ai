import asyncio
import json
from services.firebase_service import query_collection, get_document

async def test():
    providers = await query_collection("providers", limit=5)
    for p in providers:
        print(f"Provider: {p.get('name_en')} | Type: {p.get('pricing_type')} | Hourly: {p.get('hourly_rate')} | Fixed: {p.get('fixed_rate')} | Per Job: {p.get('per_job_rate')} | Rate: {p.get('rate')}")

if __name__ == "__main__":
    asyncio.run(test())
