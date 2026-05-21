import sys
sys.path.append('.')
import asyncio
from services.twilio_service import send_sms

async def main():
    # Let's try sending to a phone number. We'll use the user's phone number or a test phone number.
    # Note: we can read .env or config.
    res = await send_sms("+923001234567", "Your KaamSaaz verification code is 123456")
    print("Result:", res)

if __name__ == "__main__":
    asyncio.run(main())
