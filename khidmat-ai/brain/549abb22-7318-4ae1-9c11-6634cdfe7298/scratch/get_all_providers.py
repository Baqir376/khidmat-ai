import asyncio
import json
import os
import sys

# Add khidmat-ai/backend to sys.path so we can import services
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "khidmat-ai", "backend"))
sys.path.append(backend_path)

from services.firebase_service import get_all_documents

async def main():
    providers = await get_all_documents("providers")
    print(f"Total providers found: {len(providers)}")
    for p in providers:
        print(f"ID: {p.get('id')}, Name: {p.get('name_en')}, Phone: {p.get('phone')}, Service: {p.get('service_type_id')}, lat: {p.get('lat')}, lng: {p.get('lng')}, PricingType: {p.get('pricing_type')}, HourlyRate: {p.get('hourly_rate')}, SupabaseID: {p.get('supabase_user_id')}")

if __name__ == "__main__":
    asyncio.run(main())
