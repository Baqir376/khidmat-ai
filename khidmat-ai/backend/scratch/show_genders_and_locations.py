import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import asyncio
from services.firebase_service import get_all_documents

async def main():
    providers = await get_all_documents("providers")
    for p in providers:
        print(f"Name: {p.get('name_en')}")
        print(f"  Gender: {p.get('gender')}")
        print(f"  Lat/Lng: {p.get('lat')}, {p.get('lng')}")
        print(f"  Service type: {p.get('service_type_id')}")
        print("-" * 40)

if __name__ == "__main__":
    asyncio.run(main())
