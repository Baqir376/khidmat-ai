import asyncio, sys, os, httpx
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import config

# Test: Try to insert a test record and immediately read it back
async def main():
    SUPABASE_URL = config.SUPABASE_URL
    SUPABASE_KEY = config.SUPABASE_KEY
    
    HEADERS = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation,resolution=merge-duplicates",
    }
    base = f"{SUPABASE_URL.rstrip('/')}/rest/v1/documents"
    
    async with httpx.AsyncClient() as client:
        # INSERT a test provider
        test_payload = {
            "collection": "providers",
            "doc_id": "test-elec-001",
            "data": {
                "id": "test-elec-001",
                "name_en": "Test Electrician 1",
                "service_type_id": "electrician",
                "is_available": True,
                "lat": 33.65,
                "lng": 72.98,
                "hourly_rate": 1500,
                "area_name": "G-11 Islamabad"
            }
        }
        
        res_insert = await client.post(base, headers=HEADERS, json=test_payload)
        print(f"Insert status: {res_insert.status_code}")
        print(f"Insert body: {res_insert.text[:500]}")
        
        # READ back
        res_read = await client.get(
            f"{base}?collection=eq.providers&select=data",
            headers={**HEADERS, "Prefer": ""}
        )
        print(f"\nRead status: {res_read.status_code}")
        rows = res_read.json()
        print(f"Rows returned: {len(rows)}")
        for r in rows:
            d = r.get('data', {})
            print(f"  {d.get('name_en')} | {d.get('service_type_id')} | id={d.get('id')}")

asyncio.run(main())
