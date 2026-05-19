import asyncio
import sys
sys.path.append('.')

from services.firebase_service import get_providers_by_service
from services.maps_service import haversine_km

async def test_radius_for_location(location_name, user_lat, user_lng, womens_safety_mode):
    print(f"\n==================================================")
    print(f"Testing customer in {location_name} ({user_lat}, {user_lng})")
    print(f"Women's Safety Mode: {womens_safety_mode}")
    print(f"==================================================")
    
    gender_filter = "female" if womens_safety_mode else "male"
    providers = await get_providers_by_service(
        service_type="electrician",
        is_available=True,
        gender=gender_filter,
        limit_count=50
    )
    
    candidates = []
    print(f"Total providers found in DB with gender={gender_filter}: {len(providers)}")
    for p in providers:
        p_lat = p.get("lat") or 0
        p_lng = p.get("lng") or 0
        distance = haversine_km(user_lat, user_lng, p_lat, p_lng)
        
        status = "PASSED (Within 15km)" if distance <= 15.0 else "SKIPPED (Outside 15km)"
        print(f" - {p.get('name_en')} in {p.get('area_name')} ({p_lat}, {p_lng}): distance = {distance:.2f} km -> {status}")
        
        if distance <= 15.0:
            candidates.append(p)
            
    print(f"Final Candidates matching 15km radius: {len(candidates)}")
    for c in candidates:
        print(f"   * {c.get('name_en')} (Gender: {c.get('gender')})")

async def run_all_tests():
    # 1. Customer at Saddar, Karachi center
    await test_radius_for_location("Karachi Center (Saddar)", 24.8607, 67.0099, womens_safety_mode=True)
    await test_radius_for_location("Karachi Center (Saddar)", 24.8607, 67.0099, womens_safety_mode=False)
    
    # 2. Customer at Islamabad Center (Sector G-11)
    await test_radius_for_location("Islamabad Center (G-11)", 33.6506, 72.9639, womens_safety_mode=True)
    await test_radius_for_location("Islamabad Center (G-11)", 33.6506, 72.9639, womens_safety_mode=False)
    
    # 3. Customer in Lahore (No seeded providers)
    await test_radius_for_location("Lahore (Out of area)", 31.5204, 74.3587, womens_safety_mode=False)

if __name__ == "__main__":
    asyncio.run(run_all_tests())
