import asyncio
import sys
sys.path.append('.')

from services.firebase_service import create_document, get_document, get_all_documents
from agents.discovery_agent import run_discovery_agent
import uuid

async def test_flow():
    # 1. Create a temporary female provider
    female_id = f"test-female-{uuid.uuid4().hex[:6]}"
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
        "jobs_completed": 5,
        "cnic_verified": True,
        "experience_years": 3,
    }
    
    # Store it in providers
    await create_document("providers", female_provider, female_id)
    print(f"Created temporary female provider: {female_id}")
    
    try:
        # 2. Run discovery with womens_safety_mode=True
        print("\n--- Running discovery with womens_safety_mode=True ---")
        res_true = await run_discovery_agent(
            intent={"service_type": "electrician", "location": "Karachi"},
            user_lat=24.8607,
            user_lng=67.0099,
            session_id="test_session_true",
            womens_safety_mode=True
        )
        candidates_true = res_true.get("candidates", [])
        print(f"Found {len(candidates_true)} candidates:")
        for c in candidates_true:
            print(f" - {c.get('name_en')} (Gender: {c.get('gender')})")
            
        # 3. Run discovery with womens_safety_mode=False
        print("\n--- Running discovery with womens_safety_mode=False ---")
        res_false = await run_discovery_agent(
            intent={"service_type": "electrician", "location": "Karachi"},
            user_lat=24.8607,
            user_lng=67.0099,
            session_id="test_session_false",
            womens_safety_mode=False
        )
        candidates_false = res_false.get("candidates", [])
        print(f"Found {len(candidates_false)} candidates:")
        for c in candidates_false:
            print(f" - {c.get('name_en')} (Gender: {c.get('gender')})")

    finally:
        # Clean up by removing the document
        # (Since it's in Supabase, we can either leave it or delete/overwrite it.
        # Let's set is_available=False or keep it for manual testing if needed,
        # but let's delete it or just keep it since we want a female provider for testing the Admin panel too!)
        print("\nTesting complete.")

if __name__ == '__main__':
    asyncio.run(test_flow())
