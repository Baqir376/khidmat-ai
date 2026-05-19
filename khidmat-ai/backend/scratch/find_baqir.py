import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import asyncio
from services.firebase_service import query_collection, get_all_documents

async def main():
    providers = await query_collection("providers")
    print(f"Total providers in DB: {len(providers)}")
    baqir = None
    for p in providers:
        name = (p.get("name_en") or p.get("name") or "").lower()
        if "baqir" in name or "raza" in name:
            print(f"Found Provider: {p.get('name_en')} (ID: {p.get('id')})")
            print(f"  jobs_completed: {p.get('jobs_completed')}")
            print(f"  total_jobs: {p.get('total_jobs')}")
            baqir = p
            
    bookings = await get_all_documents("bookings")
    print(f"Total bookings in DB: {len(bookings)}")
    if baqir:
        p_bookings = [b for b in bookings if b.get("provider_id") == baqir.get("id")]
        print(f"Bookings for {baqir.get('name_en')}: {len(p_bookings)}")
        for b in p_bookings:
            print(f"  Booking ID: {b.get('id')} | Status: {b.get('status')} | Price: {b.get('final_price') or b.get('price')}")

if __name__ == '__main__':
    asyncio.run(main())
