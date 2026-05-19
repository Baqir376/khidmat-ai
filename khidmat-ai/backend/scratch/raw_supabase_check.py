import asyncio, sys, os, httpx
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import config

# Raw Supabase check - show all tables/schema and total row count
async def main():
    SUPABASE_URL = config.SUPABASE_URL
    SUPABASE_KEY = config.SUPABASE_KEY
    print(f"Supabase URL: {SUPABASE_URL}")
    
    HEADERS = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "count=exact",
    }
    
    async with httpx.AsyncClient() as client:
        # Try to get the schema information
        res = await client.get(f"{SUPABASE_URL.rstrip('/')}/rest/v1/", headers=HEADERS)
        print(f"\nSchema endpoint status: {res.status_code}")
        if res.status_code == 200:
            print(f"Schema: {res.text[:2000]}")

        # Try documents table
        base = f"{SUPABASE_URL.rstrip('/')}/rest/v1/documents"
        res2 = await client.get(base, headers=HEADERS, params={"limit": "10"})
        print(f"\nDocuments table status: {res2.status_code}")
        if res2.status_code == 200:
            rows = res2.json()
            print(f"Rows returned: {len(rows)}")
            print(f"Content-Range: {res2.headers.get('content-range', 'N/A')}")
            if rows:
                print(f"First row keys: {list(rows[0].keys())}")
                print(f"First row: {rows[0]}")
        else:
            print(f"Error: {res2.text[:500]}")

asyncio.run(main())
