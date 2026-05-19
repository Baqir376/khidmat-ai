import asyncio
from services.firebase_service import get_all_documents

async def main():
    providers = await get_all_documents("providers")
    print(f"Total providers found: {len(providers)}")
    for p in providers:
        print(p)

asyncio.run(main())
