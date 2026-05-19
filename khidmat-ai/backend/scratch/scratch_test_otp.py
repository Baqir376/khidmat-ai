import httpx
import asyncio

async def test_otp():
    url = "http://localhost:8000/api/auth/send-otp"
    payload = {"phone": "+923001234567"}
    print(f"Sending request to {url} with payload {payload}")
    async with httpx.AsyncClient() as client:
        res = await client.post(url, json=payload, timeout=10.0)
        print(f"Status: {res.status_code}")
        print(f"Response: {res.json()}")

if __name__ == "__main__":
    asyncio.run(test_otp())
