import httpx
import asyncio

async def main():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get("http://127.0.0.1:8000/api/health")
            print(f"Backend Health Status: {response.status_code}")
            print(f"Response: {response.json()}")
    except Exception as e:
        print(f"Error connecting to backend: {e}")

asyncio.run(main())
