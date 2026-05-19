import asyncio
import json
import sys
import os

# Add backend directory to sys.path so we can import services
backend_path = os.path.join(os.path.dirname(__file__), 'khidmat-ai', 'backend')
if backend_path not in sys.path:
    sys.path.append(backend_path)

from services.firebase_service import get_all_documents

async def main():
    bookings = await get_all_documents("bookings")
    print(f"--- BOOKINGS (Total: {len(bookings)}) ---")
    for b in bookings[:5]:
        print(json.dumps({
            "id": b.get("id"),
            "status": b.get("status"),
            "provider_id": b.get("provider_id"),
            "provider_name": b.get("provider_name"),
            "quoted_price": b.get("quoted_price"),
            "citizen_id": b.get("citizen_id"),
            "review_submitted": b.get("review_submitted")
        }, indent=2))
        print("-" * 20)

    providers = await get_all_documents("providers")
    print(f"\n--- PROVIDERS (Total: {len(providers)}) ---")
    for p in providers[:5]:
        print(json.dumps({
            "id": p.get("id"),
            "name": p.get("name"),
            "name_en": p.get("name_en"),
            "rating": p.get("rating"),
            "total_reviews": p.get("total_reviews")
        }, indent=2))
        print("-" * 20)

if __name__ == '__main__':
    asyncio.run(main())
