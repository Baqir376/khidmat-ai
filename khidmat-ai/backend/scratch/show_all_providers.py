import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import asyncio
from services.firebase_service import get_all_documents

async def main():
    providers = await get_all_documents("providers")
    print(f"Total providers in database: {len(providers)}")
    for p in providers:
        print(f"Name: {p.get('name_en') or p.get('name')}")
        print(f"  ID: {p.get('id')}")
        print(f"  Jobs Completed: {p.get('jobs_completed')}")
        print(f"  Rating: {p.get('rating')}")
        print(f"  Available: {p.get('is_available')}")
        print(f"  Service type: {p.get('service_type_id')}")
        print("-" * 40)

if __name__ == "__main__":
    asyncio.run(main())
