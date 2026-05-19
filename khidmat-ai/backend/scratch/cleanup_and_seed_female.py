import asyncio
import sys
sys.path.append('.')

from services.firebase_service import delete_document, create_document, get_all_documents

async def cleanup_and_seed():
    # 1. Get all providers in DB
    providers = await get_all_documents("providers")
    
    # 2. Delete existing test/duplicate female providers
    deleted_count = 0
    for p in providers:
        p_id = p.get("id")
        p_name = p.get("name_en", "")
        # Delete if id starts with 'test-female-' or name is 'Ayesha Bibi' (to clean up old ones)
        if p_id.startswith("test-female-") or p_name == "Ayesha Bibi":
            success = await delete_document("providers", p_id)
            if success:
                print(f"Deleted old female provider: {p_id} ({p_name})")
                deleted_count += 1
            else:
                print(f"Failed to delete: {p_id}")

    # 3. Create one clean female provider in the database
    female_id = "ayesha-bibi-female-1"
    female_provider = {
        "id": female_id,
        "name_en": "Ayesha Bibi",
        "name_ur": "Ayesha Bibi",
        "phone": "+923001234567",
        "service_type_id": "electrician",
        "pricing_type": "hourly",
        "hourly_rate": 900,
        "rate": 900,
        "area_name": "Saddar, Karachi",
        "lat": 24.8607,
        "lng": 67.0099,
        "gender": "female",
        "is_available": True,
        "rating": 4.8,
        "total_reviews": 3,
        "jobs_completed": 12,
        "cnic_verified": True,
        "experience_years": 3,
    }
    
    await create_document("providers", female_provider, female_id)
    print(f"\nSuccessfully seeded clean female provider: {female_id} (Ayesha Bibi)")

if __name__ == '__main__':
    asyncio.run(cleanup_and_seed())
