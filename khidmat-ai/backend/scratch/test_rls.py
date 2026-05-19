import asyncio, sys, os, httpx
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import config

# Test reading WITH the row count header to detect RLS
async def main():
    SUPABASE_URL = config.SUPABASE_URL
    SUPABASE_KEY = config.SUPABASE_KEY
    
    base = f"{SUPABASE_URL.rstrip('/')}/rest/v1/documents"
    
    HEADERS = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "count=exact",
    }
    
    async with httpx.AsyncClient() as client:
        # Check with count
        res = await client.get(f"{base}?collection=eq.providers&select=*", headers=HEADERS)
        print(f"Status: {res.status_code}")
        print(f"Content-Range: {res.headers.get('content-range', 'N/A')}")
        print(f"All response headers: {dict(res.headers)}")
        data = res.json()
        print(f"Rows: {len(data)}")
        if data:
            print(f"First row columns: {list(data[0].keys())}")
            print(f"First row data field: {data[0].get('data')}")
        
        print("\n--- Testing without select filter ---")
        res2 = await client.get(f"{base}?collection=eq.providers", headers=HEADERS)
        data2 = res2.json()
        print(f"Rows without select: {len(data2)}")
        if data2:
            print(f"Columns: {list(data2[0].keys())}")

asyncio.run(main())
