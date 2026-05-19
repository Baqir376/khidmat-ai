import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import asyncio
from services.firebase_service import get_all_documents

async def main():
    bookings = await get_all_documents("bookings")
    print(f"Total bookings in database: {len(bookings)}")
    for idx, b in enumerate(bookings):
        print(f"Booking #{idx+1}:")
        print(f"  ID: {b.get('id')}")
        print(f"  Citizen / User: {b.get('user_name') or b.get('citizen_id')}")
        print(f"  Provider ID: {b.get('provider_id')}")
        print(f"  Provider Name: {b.get('provider_name')}")
        print(f"  Status: {b.get('status')}")
        print(f"  Price: {b.get('final_price') or b.get('quoted_price') or b.get('price')}")
        print("-" * 40)

if __name__ == "__main__":
    asyncio.run(main())
