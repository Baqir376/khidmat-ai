import asyncio
import sys
from services.firebase_service import get_all_documents

# Ensure stdout uses UTF-8 to prevent cp1252 encoding error on Windows
sys.stdout.reconfigure(encoding='utf-8')

async def main():
    print("Fetching all providers...")
    providers = await get_all_documents("providers")
    print(f"Total providers found: {len(providers)}")
    for i, p in enumerate(providers):
        print(f"{i+1}. ID: {p.get('id')} | Name: {p.get('name_en')} | Phone: {p.get('phone')} | Service: {p.get('service_type_id')} | Lat: {p.get('lat')} | Lng: {p.get('lng')}")

if __name__ == '__main__':
    asyncio.run(main())
