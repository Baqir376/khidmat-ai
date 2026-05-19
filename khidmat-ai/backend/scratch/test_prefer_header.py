import asyncio, sys, os, httpx
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import config

async def main():
    SUPABASE_URL = config.SUPABASE_URL
    SUPABASE_KEY = config.SUPABASE_KEY
    
    # Test with different header combinations
    base = f"{SUPABASE_URL.rstrip('/')}/rest/v1/documents"
    
    # Headers WITH "return=representation" (same as firebase_service.py HEADERS)
    HEADERS_WITH_RETURN = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    
    # Headers WITHOUT "return=representation"
    HEADERS_NO_RETURN = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    
    async with httpx.AsyncClient() as client:
        # Test 1: GET with Prefer: return=representation
        url = f"{base}?collection=eq.providers&select=data&limit=50"
        print(f"\n=== Test 1: GET with Prefer: return=representation ===")
        res = await client.get(url, headers=HEADERS_WITH_RETURN)
        print(f"Status: {res.status_code}")
        data = res.json()
        print(f"Rows: {len(data)}")
        if data:
            print(f"First row: {data[0]}")
        
        # Test 2: GET without Prefer header
        print(f"\n=== Test 2: GET without Prefer header ===")
        res2 = await client.get(url, headers=HEADERS_NO_RETURN)
        print(f"Status: {res2.status_code}")
        data2 = res2.json()
        print(f"Rows: {len(data2)}")
        if data2:
            print(f"First row: {data2[0]}")
        
        # Test 3: Verify the test record from before exists
        url3 = f"{base}?collection=eq.providers&doc_id=eq.test-elec-001&select=data"
        print(f"\n=== Test 3: Find test-elec-001 record directly ===")
        res3 = await client.get(url3, headers=HEADERS_NO_RETURN)
        print(f"Status: {res3.status_code}")
        data3 = res3.json()
        print(f"Rows: {len(data3)}")
        if data3:
            print(f"Row: {data3[0]}")

asyncio.run(main())
