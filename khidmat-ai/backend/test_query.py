import asyncio
from services.firebase_service import get_providers_by_service

async def main():
    print("Searching for tiler...")
    providers = await get_providers_by_service("tiler", is_available=True)
    print(f"Results: {providers}")

if __name__ == "__main__":
    asyncio.run(main())
